<script setup lang="ts">
import Draggable from '@/components/Draggable.vue';
import type { XYPosition } from '@/Interface';

defineProps<{
	canMoveRight: boolean;
	canMoveLeft: boolean;
	verticalLayout?: boolean;
}>();

const emit = defineEmits<{
	drag: [e: XYPosition];
	dragstart: [];
	dragend: [];
}>();

const onDrag = (e: XYPosition) => {
	emit('drag', e);
};

const onDragEnd = () => {
	emit('dragend');
};

const onDragStart = () => {
	emit('dragstart');
};
</script>

<template>
	<Draggable
		type="panel-resize"
		:class="$style.dragContainer"
		@drag="onDrag"
		@dragstart="onDragStart"
		@dragend="onDragEnd"
	>
		<template #default="{ isDragging }">
			<div
				:class="{ [$style.dragButton]: true, [$style.verticalDragButton]: verticalLayout }"
				data-test-id="panel-drag-button"
			>
				<span
					v-if="canMoveLeft && !verticalLayout"
					:class="{ [$style.leftArrow]: true, [$style.visible]: isDragging }"
				>
					<n8n-icon icon="arrow-left" />
				</span>
				<span
					v-if="canMoveRight && !verticalLayout"
					:class="{ [$style.rightArrow]: true, [$style.visible]: isDragging }"
				>
					<n8n-icon icon="arrow-right" />
				</span>
				<!-- Vertical arrows for vertical layout -->
				<span
					v-if="canMoveLeft && verticalLayout"
					:class="{ [$style.upArrow]: true, [$style.visible]: isDragging }"
				>
					<n8n-icon icon="arrow-up" />
				</span>
				<span
					v-if="canMoveRight && verticalLayout"
					:class="{ [$style.downArrow]: true, [$style.visible]: isDragging }"
				>
					<n8n-icon icon="arrow-down" />
				</span>
				<div :class="{ [$style.grid]: true, [$style.verticalGrid]: verticalLayout }">
					<div>
						<div></div>
						<div></div>
						<div></div>
						<div></div>
						<div></div>
					</div>
					<div>
						<div></div>
						<div></div>
						<div></div>
						<div></div>
						<div></div>
					</div>
				</div>
			</div>
		</template>
	</Draggable>
</template>

<style lang="scss" module>
.dragContainer {
	pointer-events: all;
}
.dragButton {
	background-color: var(--color-background-base);
	width: 64px;
	height: 21px;
	border-top-left-radius: var(--border-radius-base);
	border-top-right-radius: var(--border-radius-base);
	cursor: grab;
	display: flex;
	align-items: center;
	justify-content: center;
	overflow: visible;
	position: relative;
	z-index: 3;

	&:hover {
		.leftArrow,
		.rightArrow,
		.upArrow,
		.downArrow {
			visibility: visible;
		}
	}
}

.verticalDragButton {
	width: 21px;
	height: 64px;
	border-top-left-radius: var(--border-radius-base);
	border-bottom-left-radius: var(--border-radius-base);
	border-top-right-radius: 0;
	border-bottom-right-radius: 0;
	// Better touch target for mobile
	min-height: 44px; // iOS recommended minimum touch target
	touch-action: pan-y;
}

.visible {
	visibility: visible !important;
}

.arrow {
	position: absolute;
	color: var(--color-background-xlight);
	font-size: var(--font-size-3xs);
	visibility: hidden;
	top: 0;
}

.leftArrow {
	composes: arrow;
	left: -16px;
}

.rightArrow {
	composes: arrow;
	right: -16px;
}

.upArrow {
	composes: arrow;
	top: -16px;
	left: 50%;
	transform: translateX(-50%);
}

.downArrow {
	composes: arrow;
	bottom: -16px;
	left: 50%;
	transform: translateX(-50%);
}

.grid {
	> div {
		display: flex;

		&:first-child {
			> div {
				margin-bottom: 2px;
			}
		}

		> div {
			height: 2px;
			width: 2px;
			border-radius: 50%;
			background-color: var(--color-foreground-xdark);
			margin-right: 4px;

			&:last-child {
				margin-right: 0;
			}
		}
	}
}

.verticalGrid {
	> div {
		display: flex;
		flex-direction: column;

		&:first-child {
			> div {
				margin-bottom: 0;
				margin-right: 2px;
			}
		}

		> div {
			height: 2px;
			width: 2px;
			border-radius: 50%;
			background-color: var(--color-foreground-xdark);
			margin-bottom: 4px;

			&:last-child {
				margin-bottom: 0;
			}
		}
	}
}
</style>
