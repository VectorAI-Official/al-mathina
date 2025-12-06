/**
 * Store Management JavaScript
 * Handles store listing, search, filtering, and detail views with lazy loading
 */

// State management
let allStores = [];
let filteredStores = [];
let currentStoreDetail = null;
let displayedStoresCount = 0;
let totalStoresCount = 0;
let isLoading = false;
let hasMoreStores = true;
const STORES_PER_PAGE = 50;
let currentFilters = {
    search: '',
    start_date: '',
    end_date: ''
};

// Date filter state
let selectedDateFilter = {
    type: 'all', // 'all', 'single', 'range'
    singleDate: null,
    startDate: null,
    endDate: null
};

// Header scroll behavior state
let lastScrollTop = 0;
let scrollTimeout;

// Initialize page
document.addEventListener('DOMContentLoaded', () => {
    loadStores(true);
    setupScrollListener();
    setupHeaderScrollBehavior();
});

// Setup header hide/show on scroll
function setupHeaderScrollBehavior() {
    const header = document.querySelector('.stores-header');
    if (!header) return;
    
    window.addEventListener('scroll', () => {
        clearTimeout(scrollTimeout);
        scrollTimeout = setTimeout(() => {
            const currentScroll = window.pageYOffset || document.documentElement.scrollTop;
            
            // Ignore if at top
            if (currentScroll <= 0) {
                header.classList.remove('header-hidden');
                return;
            }
            
            // Scrolling down - hide header
            if (currentScroll > lastScrollTop && currentScroll > 100) {
                header.classList.add('header-hidden');
            } 
            // Scrolling up - show header
            else if (currentScroll < lastScrollTop) {
                header.classList.remove('header-hidden');
            }
            
            lastScrollTop = currentScroll <= 0 ? 0 : currentScroll;
        }, 50);
    }, { passive: true });
}

// Load stores with pagination
async function loadStores(reset = false) {
    if (isLoading) return;
    if (!reset && !hasMoreStores) return;
    
    try {
        isLoading = true;
        showLoading();
        
        // Reset on new search/filter
        if (reset) {
            displayedStoresCount = 0;
            allStores = [];
            document.getElementById('storesGrid').innerHTML = '';
            hasMoreStores = true;
            
            // Update current filters (search filter only, dates are managed by date filter functions)
            currentFilters.search = document.getElementById('searchInput').value;
            // Note: currentFilters.start_date and end_date are already set by date filter functions
        }
        
        // Build URL with filters and pagination
        const params = new URLSearchParams();
        if (currentFilters.search) params.append('search', currentFilters.search);
        if (currentFilters.start_date) params.append('start_date', currentFilters.start_date);
        if (currentFilters.end_date) params.append('end_date', currentFilters.end_date);
        params.append('limit', STORES_PER_PAGE);
        params.append('skip', displayedStoresCount);
        
        const url = `/admin/api/stores/list?${params.toString()}`;
        
        const response = await fetch(url, {
            headers: {
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache'
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        
        const data = await response.json();
        const newStores = data.stores || [];
        
        allStores = [...allStores, ...newStores];
        filteredStores = [...allStores];
        hasMoreStores = data.has_more || false;
        
        displayStores(newStores);
        
        // Load statistics separately for accuracy
        if (reset) {
            await loadStatistics();
        }
        
        hideLoading();
        isLoading = false;
    } catch (error) {
        console.error('Error loading stores:', error);
        hideLoading();
        isLoading = false;
        if (displayedStoresCount === 0) {
            showEmptyState();
        }
        showToast('Failed to load stores', 'error');
    }
}

// Load statistics separately from ALL matching stores
async function loadStatistics() {
    try {
        const params = new URLSearchParams();
        if (currentFilters.search) params.append('search', currentFilters.search);
        if (currentFilters.start_date) params.append('start_date', currentFilters.start_date);
        if (currentFilters.end_date) params.append('end_date', currentFilters.end_date);
        
        const url = `/admin/api/stores/statistics?${params.toString()}`;
        
        const response = await fetch(url, {
            headers: {
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache'
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        
        const data = await response.json();
        updateStatisticsDisplay(data.statistics);
    } catch (error) {
        console.error('Error loading statistics:', error);
    }
}

// Display stores as cards (append mode for lazy loading)
function displayStores(stores) {
    const grid = document.getElementById('storesGrid');
    
    if (displayedStoresCount === 0 && stores.length === 0) {
        showEmptyState();
        grid.innerHTML = '';
        return;
    }
    
    hideEmptyState();
    
    const storesHTML = stores.map(store => `
        <div class="store-card" onclick="viewStoreDetail('${store.phone}')">
            <div class="store-card-header">
                <div class="store-icon">
                    <i class="fas fa-store"></i>
                </div>
                <div class="store-title">
                    <h3>${escapeHtml(store.store_name || 'Unnamed Store')}</h3>
                    <p class="store-phone">
                        <i class="fas fa-phone"></i> ${store.phone}
                    </p>
                </div>
            </div>
            <div class="store-card-body">
                <div class="store-info-item">
                    <i class="fas fa-user"></i>
                    <span>${escapeHtml(store.name || 'No Name')}</span>
                </div>
                <div class="store-info-item">
                    <i class="fas fa-map-marker-alt"></i>
                    <span>${escapeHtml(store.city || 'N/A')}, ${escapeHtml(store.state || 'N/A')}</span>
                </div>
                <div class="store-info-item">
                    <i class="fas fa-calendar"></i>
                    <span>Joined ${formatDate(store.created_at)}</span>
                </div>
            </div>
            <div class="store-card-footer">
                <div class="store-stat">
                    <i class="fas fa-shopping-cart"></i>
                    <span>${store.order_count} orders</span>
                </div>
                <div class="store-stat revenue">
                    <i class="fas fa-rupee-sign"></i>
                    <span>₹${formatCurrency(store.total_revenue)}</span>
                </div>
            </div>
            ${store.latest_order ? `
                <div class="store-badge">
                    <i class="fas fa-clock"></i> Last order: ${formatDateRelative(store.latest_order)}
                </div>
            ` : ''}
        </div>
    `).join('');
    
    grid.insertAdjacentHTML('beforeend', storesHTML);
    displayedStoresCount += stores.length;
}

// Update statistics display with data from separate endpoint
function updateStatisticsDisplay(statistics) {
    document.getElementById('totalStores').textContent = statistics.total_stores;
    document.getElementById('totalOrders').textContent = statistics.total_orders;
    // Display total_revenue (not just delivered)
    document.getElementById('totalRevenue').textContent = `₹${formatCurrency(statistics.total_revenue)}`;
    
    // Calculate and display average per store based on total revenue
    const avgPerStore = statistics.total_stores > 0 
        ? statistics.total_revenue / statistics.total_stores 
        : 0;
    document.getElementById('avgPerStore').textContent = `₹${formatCurrency(avgPerStore)}`;
}

// Setup infinite scroll listener
function setupScrollListener() {
    const sentinel = document.createElement('div');
    sentinel.id = 'store-load-sentinel';
    sentinel.style.height = '1px';
    document.getElementById('storesGrid').parentElement.appendChild(sentinel);
    
    const observer = new IntersectionObserver((entries) => {
        if (entries[0].isIntersecting && !isLoading && hasMoreStores) {
            loadStores(false);
        }
    }, {
        rootMargin: '200px'
    });
    
    observer.observe(sentinel);
}

// Filter stores - trigger reload
function filterStores() {
    loadStores(true);
}

// Search input handler with debounce
let searchTimeout;
function handleSearchInput() {
    const searchBtn = document.getElementById('clearSearchBtn');
    const searchInput = document.getElementById('searchInput');
    
    searchBtn.style.display = searchInput.value ? 'block' : 'none';
    
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
        filterStores();
    }, 300);
}

// Clear search
function clearSearch() {
    document.getElementById('searchInput').value = '';
    document.getElementById('clearSearchBtn').style.display = 'none';
    filterStores();
}

// Clear all filters
function clearFilters() {
    document.getElementById('searchInput').value = '';
    document.getElementById('clearSearchBtn').style.display = 'none';
    
    // Clear date filter state
    selectedDateFilter.type = 'all';
    selectedDateFilter.singleDate = null;
    selectedDateFilter.startDate = null;
    selectedDateFilter.endDate = null;
    
    document.getElementById('dateFilter').value = 'all';
    document.getElementById('dateDisplayGroup').style.display = 'none';
    
    // Clear filters for API call
    currentFilters.start_date = '';
    currentFilters.end_date = '';
    
    loadStores(true);
}

// View store detail
async function viewStoreDetail(phone) {
    try {
        showLoading();
        
        // Get date filters for revenue calculation from currentFilters
        const startDate = currentFilters.start_date;
        const endDate = currentFilters.end_date;
        
        let url = `/admin/api/stores/detail/${phone}`;
        const params = new URLSearchParams();
        if (startDate) params.append('start_date', startDate);
        if (endDate) params.append('end_date', endDate);
        if (params.toString()) url += `?${params.toString()}`;
        
        const response = await fetch(url, {
            headers: {
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache'
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        
        const data = await response.json();
        currentStoreDetail = data;
        
        displayStoreDetail(data);
        openStoreDetailModal();
        hideLoading();
    } catch (error) {
        console.error('Error loading store detail:', error);
        hideLoading();
        showToast('Failed to load store details', 'error');
    }
}

// Display store detail in modal
function displayStoreDetail(data) {
    const { store, orders, revenue } = data;
    
    // Personal information
    document.getElementById('detailStoreName').textContent = store.store_details?.store_name || 'N/A';
    document.getElementById('detailOwnerName').textContent = store.name || 'N/A';
    document.getElementById('detailPhone').textContent = store.phone;
    
    const storeDetails = store.store_details || {};
    const address = [storeDetails.street, storeDetails.landmark].filter(Boolean).join(', ') || 'N/A';
    document.getElementById('detailAddress').textContent = address;
    document.getElementById('detailCity').textContent = storeDetails.city || 'N/A';
    document.getElementById('detailState').textContent = storeDetails.state || 'N/A';
    document.getElementById('detailPincode').textContent = storeDetails.pincode || 'N/A';
    document.getElementById('detailMemberSince').textContent = formatDate(store.created_at);
    
    // Revenue statistics
    document.getElementById('detailTotalOrders').textContent = revenue.total_orders;
    document.getElementById('detailTotalRevenue').textContent = `₹${formatCurrency(revenue.total_revenue)}`;
    document.getElementById('detailDeliveredRevenue').textContent = `₹${formatCurrency(revenue.delivered_revenue)}`;
    document.getElementById('detailAvgOrderValue').textContent = `₹${formatCurrency(revenue.average_order_value)}`;
    
    document.getElementById('detailPendingOrders').textContent = revenue.pending_orders;
    document.getElementById('detailConfirmedOrders').textContent = revenue.confirmed_orders;
    document.getElementById('detailDeliveredOrders').textContent = revenue.delivered_orders;
    document.getElementById('detailCancelledOrders').textContent = revenue.cancelled_orders;
    
    // Orders
    displayStoreOrders(orders);
}

// Display store orders as slim cards
function displayStoreOrders(orders) {
    const container = document.getElementById('storeOrders');
    
    if (orders.length === 0) {
        container.innerHTML = `
            <div class="empty-orders">
                <i class="fas fa-inbox"></i>
                <p>No orders found</p>
            </div>
        `;
        return;
    }
    
    container.innerHTML = orders.map(order => {
        const statusClass = getStatusClass(order.status);
        const itemCount = order.items?.length || 0;
        
        return `
            <div class="order-slim-card ${statusClass}">
                <div class="order-slim-header">
                    <div class="order-id">
                        <i class="fas fa-receipt"></i>
                        <strong>#${order.order_id}</strong>
                    </div>
                    <div class="order-status">
                        <span class="status-badge ${statusClass}">
                            ${getStatusIcon(order.status)} ${order.status.toUpperCase()}
                        </span>
                    </div>
                </div>
                <div class="order-slim-body">
                    <div class="order-info-grid">
                        <div class="order-info-item">
                            <i class="fas fa-calendar"></i>
                            <span>${formatDate(order.created_at)}</span>
                        </div>
                        <div class="order-info-item">
                            <i class="fas fa-box"></i>
                            <span>${itemCount} item${itemCount !== 1 ? 's' : ''}</span>
                        </div>
                        <div class="order-info-item">
                            <i class="fas fa-credit-card"></i>
                            <span>${order.payment_method || 'N/A'}</span>
                        </div>
                        <div class="order-info-item revenue">
                            <i class="fas fa-rupee-sign"></i>
                            <span>₹${formatCurrency(order.total_amount)}</span>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }).join('');
}

// Show revenue details modal
async function showRevenueDetails() {
    try {
        const startDate = currentFilters.start_date;
        const endDate = currentFilters.end_date;
        
        let url = '/admin/api/stores/revenue-summary';
        const params = new URLSearchParams();
        if (startDate) params.append('start_date', startDate);
        if (endDate) params.append('end_date', endDate);
        if (params.toString()) url += `?${params.toString()}`;
        
        const response = await fetch(url, {
            headers: {
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache'
            }
        });
        
        const data = await response.json();
        const summary = data.summary;
        
        document.getElementById('revenueTotalOrders').textContent = summary.total_orders;
        document.getElementById('revenueTotalAmount').textContent = `₹${formatCurrency(summary.total_revenue)}`;
        document.getElementById('revenueDeliveredAmount').textContent = `₹${formatCurrency(summary.delivered_revenue)}`;
        document.getElementById('revenueActiveStores').textContent = summary.active_stores;
        document.getElementById('revenueAvgPerStore').textContent = `₹${formatCurrency(summary.average_per_store)}`;
        
        openRevenueModal();
    } catch (error) {
        console.error('Error loading revenue summary:', error);
        showToast('Failed to load revenue summary', 'error');
    }
}

// Modal functions
function openStoreDetailModal() {
    document.getElementById('storeDetailModal').style.display = 'flex';
    document.body.style.overflow = 'hidden';
}

function closeStoreDetail() {
    document.getElementById('storeDetailModal').style.display = 'none';
    document.body.style.overflow = 'auto';
}

function openRevenueModal() {
    document.getElementById('revenueModal').style.display = 'flex';
}

function closeRevenueModal() {
    document.getElementById('revenueModal').style.display = 'none';
}

// Close modals on outside click
window.onclick = function(event) {
    const storeModal = document.getElementById('storeDetailModal');
    const revenueModal = document.getElementById('revenueModal');
    
    if (event.target === storeModal) {
        closeStoreDetail();
    }
    if (event.target === revenueModal) {
        closeRevenueModal();
    }
};

// Loading state
function showLoading() {
    document.getElementById('loadingState').style.display = 'flex';
}

function hideLoading() {
    document.getElementById('loadingState').style.display = 'none';
}

function showEmptyState() {
    document.getElementById('emptyState').style.display = 'flex';
}

function hideEmptyState() {
    document.getElementById('emptyState').style.display = 'none';
}

// Utility functions
function formatCurrency(amount) {
    return parseFloat(amount || 0).toFixed(2);
}

function formatDate(dateString) {
    if (!dateString) return 'N/A';
    const date = new Date(dateString);
    return date.toLocaleDateString('en-IN', { 
        year: 'numeric', 
        month: 'short', 
        day: 'numeric' 
    });
}

function formatDateRelative(dateString) {
    if (!dateString) return 'Never';
    const date = new Date(dateString);
    const now = new Date();
    const diff = now - date;
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    
    if (days === 0) return 'Today';
    if (days === 1) return 'Yesterday';
    if (days < 7) return `${days} days ago`;
    if (days < 30) return `${Math.floor(days / 7)} weeks ago`;
    if (days < 365) return `${Math.floor(days / 30)} months ago`;
    return `${Math.floor(days / 365)} years ago`;
}

function getStatusClass(status) {
    const statusMap = {
        'pending': 'status-pending',
        'confirmed': 'status-confirmed',
        'delivered': 'status-delivered',
        'cancelled': 'status-cancelled'
    };
    return statusMap[status] || 'status-pending';
}

function getStatusIcon(status) {
    const iconMap = {
        'pending': '<i class="fas fa-clock"></i>',
        'confirmed': '<i class="fas fa-check"></i>',
        'delivered': '<i class="fas fa-check-circle"></i>',
        'cancelled': '<i class="fas fa-times-circle"></i>'
    };
    return iconMap[status] || '<i class="fas fa-question"></i>';
}

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function showToast(message, type = 'info') {
    // Simple toast notification
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.textContent = message;
    toast.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 15px 20px;
        background: ${type === 'error' ? '#f44336' : '#4CAF50'};
        color: white;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        z-index: 10000;
        animation: slideIn 0.3s ease;
    `;
    
    document.body.appendChild(toast);
    
    setTimeout(() => {
        toast.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// ============ DATE FILTER FUNCTIONS ============

// Handle date filter dropdown change
function handleDateFilterChange() {
    const dateFilter = document.getElementById('dateFilter').value;
    
    if (dateFilter === 'all') {
        selectedDateFilter.type = 'all';
        selectedDateFilter.singleDate = null;
        selectedDateFilter.startDate = null;
        selectedDateFilter.endDate = null;
        document.getElementById('dateDisplayGroup').style.display = 'none';
        filterStores();
    } else if (dateFilter === 'single') {
        openSingleDateModal();
    } else if (dateFilter === 'range') {
        openRangeDateModal();
    }
}

// Open single date picker modal
function openSingleDateModal() {
    const modal = document.getElementById('singleDateModal');
    const datePicker = document.getElementById('singleDatePicker');
    
    // Set max date to today
    const today = new Date().toISOString().split('T')[0];
    datePicker.max = today;
    
    // Set current value if exists
    if (selectedDateFilter.singleDate) {
        datePicker.value = selectedDateFilter.singleDate;
    } else {
        datePicker.value = today;
    }
    
    modal.style.display = 'block';
}

// Open date range picker modal
function openRangeDateModal() {
    const modal = document.getElementById('rangeDateModal');
    const startPicker = document.getElementById('startDatePicker');
    const endPicker = document.getElementById('endDatePicker');
    
    // Set max date to today
    const today = new Date().toISOString().split('T')[0];
    startPicker.max = today;
    endPicker.max = today;
    
    // Set current values if exist
    if (selectedDateFilter.startDate && selectedDateFilter.endDate) {
        startPicker.value = selectedDateFilter.startDate;
        endPicker.value = selectedDateFilter.endDate;
    } else {
        // Default to last 7 days
        const sevenDaysAgo = new Date();
        sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
        startPicker.value = sevenDaysAgo.toISOString().split('T')[0];
        endPicker.value = today;
    }
    
    modal.style.display = 'block';
}

// Close date modals
function closeDateModal() {
    document.getElementById('singleDateModal').style.display = 'none';
    document.getElementById('rangeDateModal').style.display = 'none';
    
    // Reset dropdown if user cancels
    if (selectedDateFilter.type === 'all') {
        document.getElementById('dateFilter').value = 'all';
    }
}

// Apply single date filter
function applySingleDate() {
    const datePicker = document.getElementById('singleDatePicker');
    const selectedDate = datePicker.value;
    
    if (!selectedDate) {
        alert('Please select a date');
        return;
    }
    
    selectedDateFilter.type = 'single';
    selectedDateFilter.singleDate = selectedDate;
    selectedDateFilter.startDate = null;
    selectedDateFilter.endDate = null;
    
    // Update display
    const dateObj = new Date(selectedDate);
    const dateDisplay = dateObj.toLocaleDateString('en-US', { 
        year: 'numeric', 
        month: 'short', 
        day: 'numeric' 
    });
    document.getElementById('dateDisplay').textContent = dateDisplay;
    document.getElementById('dateDisplayGroup').style.display = 'block';
    
    // Update filters for API call
    currentFilters.start_date = selectedDate;
    currentFilters.end_date = selectedDate;
    
    closeDateModal();
    filterStores();
}

// Apply date range filter
function applyDateRange() {
    const startPicker = document.getElementById('startDatePicker');
    const endPicker = document.getElementById('endDatePicker');
    const startDate = startPicker.value;
    const endDate = endPicker.value;
    
    if (!startDate || !endDate) {
        alert('Please select both start and end dates');
        return;
    }
    
    if (new Date(startDate) > new Date(endDate)) {
        alert('Start date must be before or equal to end date');
        return;
    }
    
    selectedDateFilter.type = 'range';
    selectedDateFilter.singleDate = null;
    selectedDateFilter.startDate = startDate;
    selectedDateFilter.endDate = endDate;
    
    // Update display
    const startObj = new Date(startDate);
    const endObj = new Date(endDate);
    const dateDisplay = `${startObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} - ${endObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}`;
    document.getElementById('dateDisplay').textContent = dateDisplay;
    document.getElementById('dateDisplayGroup').style.display = 'block';
    
    // Update filters for API call
    currentFilters.start_date = startDate;
    currentFilters.end_date = endDate;
    
    closeDateModal();
    filterStores();
}

// Clear date filter
function clearDateFilter() {
    selectedDateFilter.type = 'all';
    selectedDateFilter.singleDate = null;
    selectedDateFilter.startDate = null;
    selectedDateFilter.endDate = null;
    
    document.getElementById('dateFilter').value = 'all';
    document.getElementById('dateDisplayGroup').style.display = 'none';
    
    // Clear filters for API call
    currentFilters.start_date = '';
    currentFilters.end_date = '';
    
    filterStores();
}

// ============ END DATE FILTER FUNCTIONS ============

// Add animation styles
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from {
            transform: translateX(400px);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }
    @keyframes slideOut {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(400px);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);
