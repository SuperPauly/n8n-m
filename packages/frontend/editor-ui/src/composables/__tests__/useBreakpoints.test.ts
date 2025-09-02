import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { useBreakpoints } from '@/composables/useBreakpoints';

// Mock window.innerWidth
Object.defineProperty(window, 'innerWidth', {
	writable: true,
	configurable: true,
	value: 1024,
});

// Mock useDebounce composable
vi.mock('@/composables/useDebounce', () => ({
	useDebounce: () => ({
		callDebounced: vi.fn((fn) => fn()),
	}),
}));

describe('useBreakpoints', () => {
	let removeEventListenerSpy: ReturnType<typeof vi.spyOn>;
	let addEventListenerSpy: ReturnType<typeof vi.spyOn>;

	beforeEach(() => {
		addEventListenerSpy = vi.spyOn(window, 'addEventListener');
		removeEventListenerSpy = vi.spyOn(window, 'removeEventListener');
	});

	afterEach(() => {
		vi.restoreAllMocks();
	});

	it('should detect mobile breakpoint correctly', () => {
		// Set mobile width (≤768px)
		window.innerWidth = 375;
		const { isMobile, isTablet, isDesktop, bp } = useBreakpoints();

		expect(isMobile.value).toBe(true);
		expect(isTablet.value).toBe(false);
		expect(isDesktop.value).toBe(false);
		expect(bp.value).toBe('XS');
	});

	it('should detect tablet breakpoint correctly', () => {
		// Set tablet width (>768px, <1200px)
		window.innerWidth = 1000;
		const { isMobile, isTablet, isDesktop, bp } = useBreakpoints();

		expect(isMobile.value).toBe(false);
		expect(isTablet.value).toBe(true);
		expect(isDesktop.value).toBe(false);
		expect(bp.value).toBe('MD');
	});

	it('should detect desktop breakpoint correctly', () => {
		// Set desktop width (≥1200px)
		window.innerWidth = 1400;
		const { isMobile, isTablet, isDesktop, bp } = useBreakpoints();

		expect(isMobile.value).toBe(false);
		expect(isTablet.value).toBe(false);
		expect(isDesktop.value).toBe(true);
		expect(bp.value).toBe('LG');
	});

	it('should register resize event listener on mount', async () => {
		// Create a test component that uses the composable to trigger onMounted
		const TestComponent = {
			setup() {
				return useBreakpoints();
			},
			template: '<div></div>',
		};

		mount(TestComponent);
		await nextTick();

		expect(addEventListenerSpy).toHaveBeenCalledWith('resize', expect.any(Function));
	});
});