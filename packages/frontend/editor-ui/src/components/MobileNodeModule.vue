<script setup lang="ts">
import type {
	IRunDataDisplayMode,
	IUpdateInformation,
	NodePanelType,
	TargetItem,
} from '@/Interface';
import type { IRunData, NodeConnectionType, Workflow } from 'n8n-workflow';
import { computed } from 'vue';

import NodeSettings from '@/components/NodeSettings.vue';
import OutputPanel from '@/components/OutputPanel.vue';

const emit = defineEmits<{
	saveKeyboardShortcut: [event: KeyboardEvent];
	valueChanged: [parameterData: IUpdateInformation];
	switchSelectedNode: [nodeTypeName: string];
	openConnectionNodeCreator: [nodeTypeName: string, connectionType: NodeConnectionType];
	renameNode: [nodeName: string];
	stopExecution: [];
	onActivateOutputPane: [];
	onLinkRunToOutput: [];
	onUnlinkRun: [pane: string];
	onRunOutputIndexChange: [run: number];
	onOpenSettings: [];
	onOutputTableMounted: [e: { avgRowHeight: number }];
	onOutputItemHover: [e: { itemIndex: number; outputIndex: number } | null];
	onSearch: [search: string];
	onNodeExecute: [];
	onDisplayModeChange: [pane: NodePanelType, mode: IRunDataDisplayMode];
	onWorkflowActivate: [];
}>();

const props = withDefaults(
	defineProps<{
		workflowObject: Workflow;
		readOnly?: boolean;
		isProductionExecutionPreview?: boolean;
		// Node Settings props
		pushRef?: string;
		activeNodeType?: any;
		foreignCredentials?: any[];
		blockUi?: boolean;
		inputSize?: number;
		settingsEventBus?: any;
		isDragging?: boolean;
		// Output Panel props
		canLinkRuns?: boolean;
		runIndex?: number;
		linkedRuns?: boolean;
		isReadOnly?: boolean;
		isPaneActive?: boolean;
		displayMode?: IRunDataDisplayMode;
	}>(),
	{
		isProductionExecutionPreview: false,
		readOnly: false,
		foreignCredentials: () => [],
		blockUi: false,
		inputSize: 0,
		isDragging: false,
		canLinkRuns: false,
		runIndex: 0,
		linkedRuns: false,
		isReadOnly: false,
		isPaneActive: false,
	},
);

const onSwitchSelectedNode = (nodeTypeName: string) => {
	emit('switchSelectedNode', nodeTypeName);
};

const onOpenConnectionNodeCreator = (nodeTypeName: string, connectionType: NodeConnectionType) => {
	emit('openConnectionNodeCreator', nodeTypeName, connectionType);
};

const onActivateOutputPane = () => {
	emit('onActivateOutputPane');
};

const onLinkRunToOutput = () => {
	emit('onLinkRunToOutput');
};

const onUnlinkRun = (pane: string) => {
	emit('onUnlinkRun', pane);
};

const onRunOutputIndexChange = (run: number) => {
	emit('onRunOutputIndexChange', run);
};

const onOpenSettings = () => {
	emit('onOpenSettings');
};

const onOutputTableMounted = (e: { avgRowHeight: number }) => {
	emit('onOutputTableMounted', e);
};

const onOutputItemHover = (e: { itemIndex: number; outputIndex: number } | null) => {
	emit('onOutputItemHover', e);
};

const onSearch = (search: string) => {
	emit('onSearch', search);
};

const onNodeExecute = () => {
	emit('onNodeExecute');
};

const onStopExecution = () => {
	emit('stopExecution');
};

const onDisplayModeChange = (pane: NodePanelType, mode: IRunDataDisplayMode) => {
	emit('onDisplayModeChange', pane, mode);
};

const onWorkflowActivate = () => {
	emit('onWorkflowActivate');
};
</script>

<template>
	<div :class="$style.mobileNodeModule" data-test-id="mobile-node-module">
		<!-- Parameters/Settings section -->
		<section :class="$style.nodeFormsSection" aria-label="Node parameters">
			<NodeSettings
				:event-bus="settingsEventBus"
				:dragging="isDragging"
				:push-ref="pushRef"
				:node-type="activeNodeType"
				:foreign-credentials="foreignCredentials"
				:read-only="readOnly"
				:block-u-i="blockUi"
				:executable="!readOnly"
				:input-size="inputSize"
				:class="$style.nodeSettings"
				is-ndv-v2
				@execute="onNodeExecute"
				@stop-execution="onStopExecution"
				@activate="onWorkflowActivate"
				@switch-selected-node="onSwitchSelectedNode"
				@open-connection-node-creator="onOpenConnectionNodeCreator"
			/>
		</section>

		<!-- Output section -->
		<section :class="$style.nodeOutputSection" aria-label="Node output">
			<OutputPanel
				data-test-id="output-panel"
				:workflow-object="workflowObject"
				:can-link-runs="canLinkRuns"
				:run-index="runIndex"
				:linked-runs="linkedRuns"
				:push-ref="pushRef"
				:is-read-only="isReadOnly"
				:block-u-i="blockUi"
				:is-production-execution-preview="isProductionExecutionPreview"
				:is-pane-active="isPaneActive"
				:display-mode="displayMode"
				:class="$style.nodeOutput"
				@activate-pane="onActivateOutputPane"
				@link-run="onLinkRunToOutput"
				@unlink-run="onUnlinkRun"
				@run-change="onRunOutputIndexChange"
				@open-settings="onOpenSettings"
				@table-mounted="onOutputTableMounted"
				@item-hover="onOutputItemHover"
				@search="onSearch"
				@execute="onNodeExecute"
				@display-mode-change="onDisplayModeChange"
			/>
		</section>
	</div>
</template>

<style lang="scss" module>
.mobileNodeModule {
	display: flex;
	flex-direction: column;
	height: 100%;
	overflow: hidden;
}

.nodeFormsSection {
	flex: 1 1 auto;
	min-height: 0;
	overflow-y: auto;
	-webkit-overflow-scrolling: touch;
	padding: var(--spacing-m);
	background: var(--color-background-xlight);
}

.nodeSettings {
	height: 100%;
	overflow: hidden;
	flex-grow: 1;
}

.nodeOutputSection {
	flex: 0 0 28vh;
	min-height: 160px;
	max-height: 40vh;
	overflow-y: auto;
	-webkit-overflow-scrolling: touch;
	border-top: 1px solid var(--color-foreground-xweak);
	padding: var(--spacing-m);
	background: var(--color-background-base);
}

.nodeOutput {
	height: 100%;
	min-width: 100%;
}
</style>