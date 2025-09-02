import { WorkflowPage } from '../pages';

describe('Mobile node configuration layout', () => {
	const workflowPage = new WorkflowPage();

	beforeEach(() => {
		cy.viewport('iphone-8', 'portrait'); // 375x667
		workflowPage.actions.visit();
	});

	it('opens a bottom drawer with params above and output below on mobile', () => {
		// Add a node to test with
		workflowPage.actions.addNodeToCanvas('Manual Trigger');
		
		// Select the node to open configuration
		workflowPage.getters.canvasNodes().first().click();

		// Check if mobile drawer is visible
		cy.get('.mobile-node-drawer').should('be.visible');
		cy.get('.el-drawer').should('be.visible');

		// Check that the mobile node module exists with proper structure
		cy.get('[data-test-id="mobile-node-module"]').should('exist');
		
		// Verify sections exist in correct order
		cy.get('[aria-label="Node parameters"]').should('exist');
		cy.get('[aria-label="Node output"]').should('exist');

		// Check that params section comes before output section
		cy.get('[aria-label="Node parameters"]').then(($paramsSection) => {
			cy.get('[aria-label="Node output"]').then(($outputSection) => {
				const paramsPosition = $paramsSection[0].getBoundingClientRect();
				const outputPosition = $outputSection[0].getBoundingClientRect();
				expect(paramsPosition.top).to.be.lessThan(outputPosition.top);
			});
		});

		// Verify both sections are scrollable
		cy.get('[aria-label="Node parameters"]').should('have.css', 'overflow-y', 'auto');
		cy.get('[aria-label="Node output"]').should('have.css', 'overflow-y', 'auto');
	});

	it('keeps desktop layout when viewport is wide', () => {
		// Switch to desktop viewport
		cy.viewport(1280, 800);
		
		// Add and select a node
		workflowPage.actions.addNodeToCanvas('Manual Trigger');
		workflowPage.getters.canvasNodes().first().click();

		// Desktop dialog should be visible
		cy.get('[data-test-id="ndv"]').should('be.visible');
		
		// Mobile drawer should not exist
		cy.get('.mobile-node-drawer').should('not.exist');
	});

	it('allows closing the mobile drawer', () => {
		// Add and select a node
		workflowPage.actions.addNodeToCanvas('Manual Trigger');
		workflowPage.getters.canvasNodes().first().click();

		// Mobile drawer should be open
		cy.get('.mobile-node-drawer').should('be.visible');

		// Close the drawer using the close button
		cy.get('.mobile-node-drawer').within(() => {
			cy.get('[data-test-id="ndv-close"]').click();
		});

		// Drawer should be closed
		cy.get('.mobile-node-drawer').should('not.be.visible');
	});
});