<script lang="ts" setup>
import { useStorage } from '@/composables/useStorage';

import type { INodeTypeDescription } from 'n8n-workflow';
import PanelDragButton from './PanelDragButton.vue';

import { LOCAL_STORAGE_MAIN_PANEL_RELATIVE_WIDTH, MAIN_NODE_PANEL_WIDTH } from '@/constants';
import { useNDVStore } from '@/stores/ndv.store';
import { ndvEventBus } from '@/event-bus';
import NDVFloatingNodes from '@/components/NDVFloatingNodes.vue';
import type { Direction, MainPanelType, XYPosition } from '@/Interface';
import { ref, onMounted, onBeforeUnmount, computed, watch, nextTick } from 'vue';
import { useUIStore } from '@/stores/ui.store';
import { useThrottleFn } from '@vueuse/core';

const SIDE_MARGIN = 24;
const SIDE_PANELS_MARGIN = 80;
const MIN_PANEL_WIDTH = 310;
const PANEL_WIDTH = 350;
const PANEL_WIDTH_LARGE = 420;
const MIN_WINDOW_WIDTH = 2 * (SIDE_MARGIN + SIDE_PANELS_MARGIN) + MIN_PANEL_WIDTH;

// Vertical layout constants
const TOP_BOTTOM_MARGIN = 24;
const VERTICAL_PANELS_MARGIN = 60;
const MIN_PANEL_HEIGHT = 200;
const PANEL_HEIGHT = 250;
const PANEL_HEIGHT_LARGE = 300;
const MIN_WINDOW_HEIGHT = 3 * MIN_PANEL_HEIGHT + 2 * VERTICAL_PANELS_MARGIN + 2 * TOP_BOTTOM_MARGIN;

const initialMainPanelWidth: Record<MainPanelType, number> = {
	regular: MAIN_NODE_PANEL_WIDTH,
	dragless: MAIN_NODE_PANEL_WIDTH,
	unknown: MAIN_NODE_PANEL_WIDTH,
	inputless: MAIN_NODE_PANEL_WIDTH,
	wide: MAIN_NODE_PANEL_WIDTH * 2,
};

const initialMainPanelHeight: Record<MainPanelType, number> = {
	regular: PANEL_HEIGHT,
	dragless: PANEL_HEIGHT,
	unknown: PANEL_HEIGHT,
	inputless: PANEL_HEIGHT,
	wide: PANEL_HEIGHT_LARGE,
};

interface Props {
	isDraggable: boolean;
	hideInputAndOutput: boolean;
	nodeType: INodeTypeDescription | null;
}

const throttledOnResize = useThrottleFn(onResize, 100);

const ndvStore = useNDVStore();
const uiStore = useUIStore();

const props = defineProps<Props>();

const isDragging = ref<boolean>(false);
const initialized = ref<boolean>(false);
const containerWidth = ref<number>(uiStore.appGridDimensions.width);
const mainPanelVerticalPosition = ref<number>(0);

const emit = defineEmits<{
	init: [{ position: number }];
	dragstart: [{ position: number }];
	dragend: [{ position: number; windowWidth: number }];
	switchSelectedNode: [string];
	close: [];
}>();

const slots = defineSlots<{
	input: unknown;
	output: unknown;
	main: unknown;
}>();

onMounted(() => {
	/*
		Only set(or restore) initial position if `mainPanelDimensions`
		is at the default state({relativeLeft:1, relativeRight: 1, relativeWidth: 1}) to make sure we use store values if they are set
	*/
	if (
		mainPanelDimensions.value.relativeLeft === 1 &&
		mainPanelDimensions.value.relativeRight === 1
	) {
		setMainPanelWidth();
		setPositions(getInitialLeftPosition(mainPanelDimensions.value.relativeWidth));
		restorePositionData();
	}

	emit('init', { position: mainPanelDimensions.value.relativeLeft });
	setTimeout(() => {
		initialized.value = true;
	}, 0);

	ndvEventBus.on('setPositionByName', setPositionByName);
});

onBeforeUnmount(() => {
	ndvEventBus.off('setPositionByName', setPositionByName);
});

watch(
	() => uiStore.appGridDimensions,
	async (dimensions) => {
		const ndv = document.getElementById('ndv');
		if (ndv) {
			await nextTick();
			const { width: ndvWidth } = ndv.getBoundingClientRect();
			containerWidth.value = ndvWidth;
		} else {
			containerWidth.value = dimensions.width;
		}
		const minRelativeWidth = pxToRelativeWidth(MIN_PANEL_WIDTH);
		const isBelowMinWidthMainPanel = mainPanelDimensions.value.relativeWidth < minRelativeWidth;

		// Prevent the panel resizing below MIN_PANEL_WIDTH while maintain position
		if (isBelowMinWidthMainPanel) {
			setMainPanelWidth(minRelativeWidth);
		}

		const isBelowMinLeft = minimumLeftPosition.value > mainPanelDimensions.value.relativeLeft;
		const isMaxRight = maximumRightPosition.value > mainPanelDimensions.value.relativeRight;

		// When user is resizing from non-supported view(sub ~488px) we need to refit the panels
		if (dimensions.width > MIN_WINDOW_WIDTH && isBelowMinLeft && isMaxRight) {
			setMainPanelWidth(minRelativeWidth);
			setPositions(getInitialLeftPosition(mainPanelDimensions.value.relativeWidth));
		}

		setPositions(mainPanelDimensions.value.relativeLeft);
	},
);

const currentNodePaneType = computed((): MainPanelType => {
	if (!hasInputSlot.value) return 'inputless';
	if (!props.isDraggable) return 'dragless';
	if (props.nodeType === null) return 'unknown';
	return props.nodeType.parameterPane ?? 'regular';
});

const useVerticalLayout = computed((): boolean => {
	// Use vertical layout for mobile/portrait screens or when height > width
	const { width, height } = uiStore.appGridDimensions;
	// Enable vertical layout for:
	// 1. Portrait orientation (height > width)
	// 2. Mobile screens (width < 768px)
	// 3. Touch devices (detected via CSS media query support)
	const isMobile = width < 768;
	const isPortrait = height > width;
	const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;

	return (isPortrait && isTouchDevice) || isMobile;
});

const mainPanelDimensions = computed(() => {
	return ndvStore.mainPanelDimensions[currentNodePaneType.value];
});

const calculatedPositions = computed(
	(): { inputPanelRelativeRight: number; outputPanelRelativeLeft: number } => {
		const hasInput = slots.input !== undefined;
		const outputPanelRelativeLeft =
			mainPanelDimensions.value.relativeLeft + mainPanelDimensions.value.relativeWidth;

		const inputPanelRelativeRight = hasInput
			? 1 - outputPanelRelativeLeft + mainPanelDimensions.value.relativeWidth
			: 1 - pxToRelativeWidth(SIDE_MARGIN);

		return {
			inputPanelRelativeRight,
			outputPanelRelativeLeft,
		};
	},
);

const calculatedVerticalPositions = computed(
	(): {
		inputPanelRelativeBottom: number;
		outputPanelRelativeTop: number;
		mainPanelRelativeTop: number;
		mainPanelRelativeBottom: number;
	} => {
		const hasInput = slots.input !== undefined;
		const containerHeight = uiStore.appGridDimensions.height;

		// Default heights for each panel (in pixels)
		const inputPanelHeight = hasInput ? PANEL_HEIGHT : 0;
		const mainPanelHeight = initialMainPanelHeight[currentNodePaneType.value];
		const outputPanelHeight = PANEL_HEIGHT;

		// Convert to relative positions (0-1)
		const inputPanelRelativeHeight = inputPanelHeight / containerHeight;
		const mainPanelRelativeHeight = mainPanelHeight / containerHeight;
		const outputPanelRelativeHeight = outputPanelHeight / containerHeight;

		// Calculate positions from top
		const inputPanelRelativeTop = pxToRelativeHeight(TOP_BOTTOM_MARGIN);
		const mainPanelRelativeTop =
			inputPanelRelativeTop + inputPanelRelativeHeight + pxToRelativeHeight(VERTICAL_PANELS_MARGIN);
		const outputPanelRelativeTop =
			mainPanelRelativeTop + mainPanelRelativeHeight + pxToRelativeHeight(VERTICAL_PANELS_MARGIN);

		return {
			inputPanelRelativeBottom: 1 - inputPanelRelativeTop - inputPanelRelativeHeight,
			outputPanelRelativeTop,
			mainPanelRelativeTop,
			mainPanelRelativeBottom: 1 - mainPanelRelativeTop - mainPanelRelativeHeight,
		};
	},
);

const outputPanelRelativeTranslate = computed((): number => {
	const panelMinLeft = 1 - pxToRelativeWidth(MIN_PANEL_WIDTH + SIDE_MARGIN);
	const currentRelativeLeftDelta = calculatedPositions.value.outputPanelRelativeLeft - panelMinLeft;
	return currentRelativeLeftDelta > 0 ? currentRelativeLeftDelta : 0;
});

const supportedResizeDirections = computed((): Direction[] => {
	const supportedDirections = ['right' as Direction];

	if (props.isDraggable) supportedDirections.push('left');
	return supportedDirections;
});

const hasInputSlot = computed((): boolean => {
	return slots.input !== undefined;
});

const inputPanelMargin = computed(() => pxToRelativeWidth(SIDE_PANELS_MARGIN));

const minimumLeftPosition = computed((): number => {
	if (containerWidth.value < MIN_WINDOW_WIDTH) return pxToRelativeWidth(1);

	if (!hasInputSlot.value) return pxToRelativeWidth(SIDE_MARGIN);
	return pxToRelativeWidth(SIDE_MARGIN + 20) + inputPanelMargin.value;
});

const maximumRightPosition = computed((): number => {
	if (containerWidth.value < MIN_WINDOW_WIDTH) return pxToRelativeWidth(1);

	return pxToRelativeWidth(SIDE_MARGIN + 20) + inputPanelMargin.value;
});

const canMoveLeft = computed((): boolean => {
	return mainPanelDimensions.value.relativeLeft > minimumLeftPosition.value;
});

const canMoveRight = computed((): boolean => {
	return mainPanelDimensions.value.relativeRight > maximumRightPosition.value;
});

const mainPanelStyles = computed((): { left: string; right: string } => {
	return {
		left: `${relativeWidthToPx(mainPanelDimensions.value.relativeLeft)}px`,
		right: `${relativeWidthToPx(mainPanelDimensions.value.relativeRight)}px`,
	};
});

const inputPanelStyles = computed((): { right: string } => {
	return {
		right: `${relativeWidthToPx(calculatedPositions.value.inputPanelRelativeRight)}px`,
	};
});

const outputPanelStyles = computed((): { left: string; transform: string } => {
	return {
		left: `${relativeWidthToPx(calculatedPositions.value.outputPanelRelativeLeft)}px`,
		transform: `translateX(-${relativeWidthToPx(outputPanelRelativeTranslate.value)}px)`,
	};
});

const verticalInputPanelStyles = computed(
	(): { top: string; bottom: string; left: string; right: string } => {
		const mainPanelTop =
			mainPanelVerticalPosition.value || calculatedVerticalPositions.value.mainPanelRelativeTop;
		const inputBottom = 1 - mainPanelTop + pxToRelativeHeight(VERTICAL_PANELS_MARGIN);

		return {
			top: `${TOP_BOTTOM_MARGIN}px`,
			bottom: `${relativeHeightToPx(inputBottom)}px`,
			left: `${SIDE_MARGIN}px`,
			right: `${SIDE_MARGIN}px`,
		};
	},
);

const verticalMainPanelStyles = computed(
	(): { top: string; bottom: string; left: string; right: string } => {
		const topPosition =
			mainPanelVerticalPosition.value || calculatedVerticalPositions.value.mainPanelRelativeTop;
		const mainPanelHeight = initialMainPanelHeight[currentNodePaneType.value];
		const bottomPosition = 1 - topPosition - mainPanelHeight / uiStore.appGridDimensions.height;

		return {
			top: `${relativeHeightToPx(topPosition)}px`,
			bottom: `${relativeHeightToPx(bottomPosition)}px`,
			left: `${SIDE_MARGIN}px`,
			right: `${SIDE_MARGIN}px`,
		};
	},
);

const verticalOutputPanelStyles = computed(
	(): { top: string; bottom: string; left: string; right: string } => {
		const mainPanelTop =
			mainPanelVerticalPosition.value || calculatedVerticalPositions.value.mainPanelRelativeTop;
		const mainPanelHeight = initialMainPanelHeight[currentNodePaneType.value];
		const outputTop =
			mainPanelTop +
			mainPanelHeight / uiStore.appGridDimensions.height +
			pxToRelativeHeight(VERTICAL_PANELS_MARGIN);

		return {
			top: `${relativeHeightToPx(outputTop)}px`,
			bottom: `${TOP_BOTTOM_MARGIN}px`,
			left: `${SIDE_MARGIN}px`,
			right: `${SIDE_MARGIN}px`,
		};
	},
);

const hasDoubleWidth = computed((): boolean => {
	return props.nodeType?.parameterPane === 'wide';
});

const fixedPanelWidth = computed((): number => {
	const multiplier = hasDoubleWidth.value ? 2 : 1;

	if (containerWidth.value > 1700) {
		return PANEL_WIDTH_LARGE * multiplier;
	}

	return PANEL_WIDTH * multiplier;
});

const onSwitchSelectedNode = (node: string) => emit('switchSelectedNode', node);

function getInitialLeftPosition(width: number): number {
	if (currentNodePaneType.value === 'dragless')
		return pxToRelativeWidth(SIDE_MARGIN + 1 + fixedPanelWidth.value);

	return hasInputSlot.value ? 0.5 - width / 2 : minimumLeftPosition.value;
}

function setMainPanelWidth(relativeWidth?: number): void {
	const mainPanelRelativeWidth =
		relativeWidth || pxToRelativeWidth(initialMainPanelWidth[currentNodePaneType.value]);

	ndvStore.setMainPanelDimensions({
		panelType: currentNodePaneType.value,
		dimensions: {
			relativeWidth: mainPanelRelativeWidth,
		},
	});
}

function setPositions(relativeLeft: number): void {
	const mainPanelRelativeLeft =
		relativeLeft || 1 - calculatedPositions.value.inputPanelRelativeRight;
	const mainPanelRelativeRight =
		1 - mainPanelRelativeLeft - mainPanelDimensions.value.relativeWidth;

	const isMaxRight = maximumRightPosition.value > mainPanelRelativeRight;
	const isMinLeft = minimumLeftPosition.value > mainPanelRelativeLeft;
	const isInputless = currentNodePaneType.value === 'inputless';

	if (isMinLeft) {
		ndvStore.setMainPanelDimensions({
			panelType: currentNodePaneType.value,
			dimensions: {
				relativeLeft: minimumLeftPosition.value,
				relativeRight: 1 - mainPanelDimensions.value.relativeWidth - minimumLeftPosition.value,
			},
		});
		return;
	}

	if (isMaxRight) {
		ndvStore.setMainPanelDimensions({
			panelType: currentNodePaneType.value,
			dimensions: {
				relativeLeft: 1 - mainPanelDimensions.value.relativeWidth - maximumRightPosition.value,
				relativeRight: maximumRightPosition.value,
			},
		});
		return;
	}

	ndvStore.setMainPanelDimensions({
		panelType: currentNodePaneType.value,
		dimensions: {
			relativeLeft: isInputless ? minimumLeftPosition.value : mainPanelRelativeLeft,
			relativeRight: mainPanelRelativeRight,
		},
	});
}

function setVerticalPositions(relativeTop: number): void {
	// For vertical layout, we'll store the main panel's top position
	// This is a simplified version - in a full implementation, you'd want to
	// store vertical dimensions in the NDV store similar to horizontal dimensions
	const containerHeight = uiStore.appGridDimensions.height;
	const mainPanelHeight = initialMainPanelHeight[currentNodePaneType.value];
	const minTop = pxToRelativeHeight(TOP_BOTTOM_MARGIN + PANEL_HEIGHT + VERTICAL_PANELS_MARGIN);
	const maxTop =
		1 -
		pxToRelativeHeight(TOP_BOTTOM_MARGIN + PANEL_HEIGHT + VERTICAL_PANELS_MARGIN) -
		mainPanelHeight / containerHeight;

	// Constrain the position
	const constrainedTop = Math.max(minTop, Math.min(maxTop, relativeTop));

	// For now, we'll just update a reactive ref to trigger re-renders
	// In a full implementation, you'd want to store this in the NDV store
	mainPanelVerticalPosition.value = constrainedTop;
}

function setPositionByName(position: 'minLeft' | 'maxRight' | 'initial') {
	const positionByName: Record<string, number> = {
		minLeft: minimumLeftPosition.value,
		maxRight: maximumRightPosition.value,
		initial: getInitialLeftPosition(mainPanelDimensions.value.relativeWidth),
	};

	setPositions(positionByName[position]);
}

function pxToRelativeWidth(px: number): number {
	return px / containerWidth.value;
}

function relativeWidthToPx(relativeWidth: number) {
	return relativeWidth * containerWidth.value;
}

function pxToRelativeHeight(px: number): number {
	return px / uiStore.appGridDimensions.height;
}

function relativeHeightToPx(relativeHeight: number) {
	return relativeHeight * uiStore.appGridDimensions.height;
}

function onResizeEnd() {
	storePositionData();
}

function onResizeThrottle(data: { direction: string; x: number; width: number }) {
	if (initialized.value) {
		void throttledOnResize(data);
	}
}

function onResize({ direction, x, width }: { direction: string; x: number; width: number }) {
	const relativeDistance = pxToRelativeWidth(x);
	const relativeWidth = pxToRelativeWidth(width);

	if (direction === 'left' && relativeDistance <= minimumLeftPosition.value) return;
	if (direction === 'right' && 1 - relativeDistance <= maximumRightPosition.value) return;
	if (width <= MIN_PANEL_WIDTH) return;

	setMainPanelWidth(relativeWidth);
	setPositions(direction === 'left' ? relativeDistance : mainPanelDimensions.value.relativeLeft);
}

function restorePositionData() {
	const storedPanelWidthData = useStorage(
		`${LOCAL_STORAGE_MAIN_PANEL_RELATIVE_WIDTH}_${currentNodePaneType.value}`,
	).value;

	if (storedPanelWidthData) {
		const parsedWidth = parseFloat(storedPanelWidthData);
		setMainPanelWidth(parsedWidth);
		const initialPosition = getInitialLeftPosition(parsedWidth);

		setPositions(initialPosition);
		return true;
	}
	return false;
}

function storePositionData() {
	useStorage(`${LOCAL_STORAGE_MAIN_PANEL_RELATIVE_WIDTH}_${currentNodePaneType.value}`).value =
		mainPanelDimensions.value.relativeWidth.toString();
}

function onDragStart() {
	isDragging.value = true;
	emit('dragstart', { position: mainPanelDimensions.value.relativeLeft });
}

function onDrag(position: XYPosition) {
	if (useVerticalLayout.value) {
		// Vertical drag logic - adjust panel heights
		const relativeTop =
			pxToRelativeHeight(position[1]) -
			initialMainPanelHeight[currentNodePaneType.value] / uiStore.appGridDimensions.height / 2;
		setVerticalPositions(relativeTop);
	} else {
		// Horizontal drag logic (original)
		const relativeLeft =
			pxToRelativeWidth(position[0]) - mainPanelDimensions.value.relativeWidth / 2;
		setPositions(relativeLeft);
	}
}

function onDragEnd() {
	setTimeout(() => {
		isDragging.value = false;
		emit('dragend', {
			windowWidth: containerWidth.value,
			position: mainPanelDimensions.value.relativeLeft,
		});
	}, 0);
	storePositionData();
}
</script>

<template>
	<div>
		<NDVFloatingNodes
			v-if="ndvStore.activeNode"
			:root-node="ndvStore.activeNode"
			@switch-selected-node="onSwitchSelectedNode"
		/>
		<div
			v-if="!hideInputAndOutput"
			:class="useVerticalLayout ? $style.verticalInputPanel : $style.inputPanel"
			:style="useVerticalLayout ? verticalInputPanelStyles : inputPanelStyles"
		>
			<slot name="input"></slot>
		</div>
		<div
			v-if="!hideInputAndOutput"
			:class="useVerticalLayout ? $style.verticalOutputPanel : $style.outputPanel"
			:style="useVerticalLayout ? verticalOutputPanelStyles : outputPanelStyles"
		>
			<slot name="output"></slot>
		</div>
		<div
			:class="useVerticalLayout ? $style.verticalMainPanel : $style.mainPanel"
			:style="useVerticalLayout ? verticalMainPanelStyles : mainPanelStyles"
		>
			<N8nResizeWrapper
				:is-resizing-enabled="currentNodePaneType !== 'unknown'"
				:width="relativeWidthToPx(mainPanelDimensions.relativeWidth)"
				:min-width="MIN_PANEL_WIDTH"
				:grid-size="20"
				:supported-directions="supportedResizeDirections"
				outset
				@resize="onResizeThrottle"
				@resizeend="onResizeEnd"
			>
				<div
					:class="
						useVerticalLayout ? $style.verticalDragButtonContainer : $style.dragButtonContainer
					"
				>
					<PanelDragButton
						v-if="!hideInputAndOutput && isDraggable"
						:class="{ [$style.draggable]: true, [$style.visible]: isDragging }"
						:can-move-left="canMoveLeft"
						:can-move-right="canMoveRight"
						:vertical-layout="useVerticalLayout"
						@dragstart="onDragStart"
						@drag="onDrag"
						@dragend="onDragEnd"
					/>
				</div>
				<div :class="{ [$style.mainPanelInner]: true, [$style.dragging]: isDragging }">
					<slot name="main" />
				</div>
			</N8nResizeWrapper>
		</div>
	</div>
</template>

<style lang="scss" module>
.dataPanel {
	position: absolute;
	height: calc(100% - 2 * var(--spacing-l));
	position: absolute;
	top: var(--spacing-l);
	z-index: 0;
	min-width: 280px;
}

.inputPanel {
	composes: dataPanel;
	left: var(--spacing-l);

	> * {
		border-radius: var(--border-radius-large) 0 0 var(--border-radius-large);
	}
}

.outputPanel {
	composes: dataPanel;
	right: var(--spacing-l);

	> * {
		border-radius: 0 var(--border-radius-large) var(--border-radius-large) 0;
	}
}

// Vertical layout styles
.verticalInputPanel {
	position: absolute;
	z-index: 0;
	min-height: 150px;
	// Better touch targets for mobile
	touch-action: pan-y;

	> * {
		border-radius: var(--border-radius-large) var(--border-radius-large) 0 0;
		height: 100%;
	}
}

.verticalMainPanel {
	position: absolute;
	z-index: 1;
	// Better touch targets for mobile
	touch-action: pan-y;

	&:hover {
		.draggable {
			visibility: visible;
		}
	}

	// Show drag handle on touch devices without hover
	@media (hover: none) and (pointer: coarse) {
		.draggable {
			visibility: visible;
			opacity: 0.7;
		}
	}
}

.verticalOutputPanel {
	position: absolute;
	z-index: 0;
	min-height: 150px;
	// Better touch targets for mobile
	touch-action: pan-y;

	> * {
		border-radius: 0 0 var(--border-radius-large) var(--border-radius-large);
		height: 100%;
	}
}

.mainPanel {
	position: absolute;
	height: 100%;

	&:hover {
		.draggable {
			visibility: visible;
		}
	}
}

.mainPanelInner {
	height: 100%;
	border: var(--border-base);
	border-radius: var(--border-radius-large);
	box-shadow: 0 4px 16px rgb(50 61 85 / 10%);
	overflow: hidden;

	&.dragging {
		border-color: var(--color-primary);
		box-shadow: 0 6px 16px rgba(255, 74, 51, 0.15);
	}
}

.draggable {
	visibility: hidden;
}

.double-width {
	left: 90%;
}

.dragButtonContainer {
	position: absolute;
	top: -12px;
	width: 100%;
	height: 12px;
	display: flex;
	justify-content: center;
	pointer-events: none;

	.draggable {
		pointer-events: all;
	}
	&:hover .draggable {
		visibility: visible;
	}
}

.verticalDragButtonContainer {
	position: absolute;
	left: -12px;
	height: 100%;
	width: 12px;
	display: flex;
	align-items: center;
	pointer-events: none;

	.draggable {
		pointer-events: all;
	}
	&:hover .draggable {
		visibility: visible;
	}
}

.visible {
	visibility: visible;
}
</style>
