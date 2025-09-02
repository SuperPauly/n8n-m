import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { BREAKPOINT_SM, BREAKPOINT_MD, BREAKPOINT_LG, BREAKPOINT_XL } from '@/constants';
import { useDebounce } from '@/composables/useDebounce';

/**
 * Composable for responsive breakpoint detection
 * Provides reactive width and breakpoint information
 */
export function useBreakpoints() {
	const { callDebounced } = useDebounce();
	const width = ref(window.innerWidth);

	const bp = computed(() => {
		if (width.value < BREAKPOINT_SM) {
			return 'XS';
		}
		if (width.value >= BREAKPOINT_XL) {
			return 'XL';
		}
		if (width.value >= BREAKPOINT_LG) {
			return 'LG';
		}
		if (width.value >= BREAKPOINT_MD) {
			return 'MD';
		}
		return 'SM';
	});

	const isMobile = computed(() => width.value <= BREAKPOINT_SM);
	const isTablet = computed(() => width.value > BREAKPOINT_SM && width.value < BREAKPOINT_LG);
	const isDesktop = computed(() => width.value >= BREAKPOINT_LG);

	const onResize = () => {
		void callDebounced(onResizeEnd, { debounceTime: 50 });
	};

	const onResizeEnd = () => {
		width.value = window.innerWidth;
	};

	onMounted(() => {
		window.addEventListener('resize', onResize);
	});

	onBeforeUnmount(() => {
		window.removeEventListener('resize', onResize);
	});

	return {
		width,
		bp,
		isMobile,
		isTablet,
		isDesktop,
	};
}