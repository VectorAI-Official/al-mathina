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
        <div class="store-card">
            <div class="store-card-content" onclick="viewStoreDetail('${store.phone}')">
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
            <button class="delete-store-btn" onclick="event.stopPropagation(); deleteUserProfile('${store.phone}', '${escapeHtml(store.store_name || 'Unnamed Store')}')" title="Delete user profile">
                <i class="fas fa-trash-alt"></i>
            </button>
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
            <div class="order-slim-card ${statusClass}" onclick="viewOrderDetails('${order.order_id}')" style="cursor: pointer;" title="Click to view order details">
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

function formatDateTime(dateString) {
    if (!dateString) return 'N/A';
    const date = new Date(dateString);
    const options = { 
        year: 'numeric', 
        month: 'short', 
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
    };
    return date.toLocaleString('en-US', options);
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

// ============ PDF EXPORT FUNCTION ============
let exportStoreList = [];
let exportFilteredList = [];
let exportSelectedList = [];
let exportSearchTerm = '';
let exportDateFilter = { type: 'all', singleDate: null, startDate: null, endDate: null };

function openExportModal() {
    document.getElementById('exportPreviewBody').innerHTML = '<tr><td colspan="3" style="text-align:center; padding:20px;">Loading...</td></tr>';
    document.getElementById('exportSearchInput').value = '';
    document.getElementById('exportSearchClear').style.display = 'none';
    document.getElementById('exportSearchResults').style.display = 'none';
    document.getElementById('exportDateFilter').value = 'all';
    document.getElementById('exportDateDisplayGroup').style.display = 'none';
    exportSearchTerm = '';
    exportDateFilter = { type: 'all', singleDate: null, startDate: null, endDate: null };
    document.getElementById('exportModal').style.display = 'block';
    loadExportData();
}

function closeExportModal() {
    document.getElementById('exportModal').style.display = 'none';
}

async function handleExportSearch() {
    exportSearchTerm = document.getElementById('exportSearchInput').value.toLowerCase();
    const clearBtn = document.getElementById('exportSearchClear');
    clearBtn.style.display = exportSearchTerm ? 'block' : 'none';
    
    if (exportSearchTerm) {
        // Query database with date filter + search term
        await searchExportStores(exportSearchTerm);
    } else {
        // No search term - hide search results
        document.getElementById('exportSearchResults').style.display = 'none';
    }
}

function clearExportSearch() {
    document.getElementById('exportSearchInput').value = '';
    document.getElementById('exportSearchClear').style.display = 'none';
    exportSearchTerm = '';
    document.getElementById('exportSearchResults').style.display = 'none';
}

// Search stores from database with date filter applied
async function searchExportStores(searchTerm) {
    try {
        const params = new URLSearchParams();
        params.append('search', searchTerm);
        
        // Apply date filter to search query
        if (exportDateFilter.type === 'single' && exportDateFilter.singleDate) {
            params.append('start_date', exportDateFilter.singleDate);
            params.append('end_date', exportDateFilter.singleDate);
        } else if (exportDateFilter.type === 'range' && exportDateFilter.startDate && exportDateFilter.endDate) {
            params.append('start_date', exportDateFilter.startDate);
            params.append('end_date', exportDateFilter.endDate);
        }
        
        params.append('limit', 10);
        params.append('skip', 0);
        
        const response = await fetch(`/admin/api/stores/list?${params.toString()}`, {
            headers: { 'Cache-Control': 'no-cache', 'Pragma': 'no-cache' }
        });
        
        const data = await response.json();
        const searchResults = data.stores || [];
        
        renderExportSearchResults(searchResults);
    } catch (err) {
        console.error('Export search failed', err);
        document.getElementById('exportSearchResults').innerHTML = '<div style="padding:12px; color:#d32f2f; text-align:center;">Search failed</div>';
        document.getElementById('exportSearchResults').style.display = 'block';
    }
}

function handleExportDateFilterChange() {
    const exportDateFilter = document.getElementById('exportDateFilter');
    const selectedValue = exportDateFilter.value;
    
    if (selectedValue === 'single') {
        openExportSingleDateModal();
    } else if (selectedValue === 'range') {
        openExportRangeDateModal();
    } else if (selectedValue === 'all') {
        clearExportDateFilter();
    }
}

function openExportSingleDateModal() {
    const singleDateModal = document.getElementById('singleDateModal');
    const datePicker = document.getElementById('singleDatePicker');
    
    // Set max date to today
    const today = new Date().toISOString().split('T')[0];
    datePicker.max = today;
    
    // Set current value if exists
    if (exportDateFilter.singleDate) {
        datePicker.value = exportDateFilter.singleDate;
    } else {
        datePicker.value = today;
    }
    
    // Store context that this is for export
    sessionStorage.setItem('dateFilterContext', 'export');
    singleDateModal.style.display = 'block';
}

function openExportRangeDateModal() {
    const modal = document.getElementById('rangeDateModal');
    const startPicker = document.getElementById('startDatePicker');
    const endPicker = document.getElementById('endDatePicker');
    
    // Set max date to today
    const today = new Date().toISOString().split('T')[0];
    startPicker.max = today;
    endPicker.max = today;
    
    // Set current values if exist
    if (exportDateFilter.startDate && exportDateFilter.endDate) {
        startPicker.value = exportDateFilter.startDate;
        endPicker.value = exportDateFilter.endDate;
    } else {
        // Default to last 7 days
        const sevenDaysAgo = new Date();
        sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
        startPicker.value = sevenDaysAgo.toISOString().split('T')[0];
        endPicker.value = today;
    }
    
    // Store context that this is for export
    sessionStorage.setItem('dateFilterContext', 'export');
    modal.style.display = 'block';
}

function clearExportDateFilter() {
    exportDateFilter.type = 'all';
    exportDateFilter.singleDate = null;
    exportDateFilter.startDate = null;
    exportDateFilter.endDate = null;
    
    document.getElementById('exportDateFilter').value = 'all';
    document.getElementById('exportDateDisplayGroup').style.display = 'none';
    
    // Also clear search to show all results
    exportSearchTerm = '';
    document.getElementById('exportSearchInput').value = '';
    document.getElementById('exportSearchClear').style.display = 'none';
    
    // Reload export data with all dates
    loadExportData();
}

async function addStoreFromSearch(storeName) {
    if (!storeName) return;
    
    try {
        // Fetch the store data from database to get complete info
        const params = new URLSearchParams();
        params.append('search', storeName);
        
        // Apply current date filter
        if (exportDateFilter.type === 'single' && exportDateFilter.singleDate) {
            params.append('start_date', exportDateFilter.singleDate);
            params.append('end_date', exportDateFilter.singleDate);
        } else if (exportDateFilter.type === 'range' && exportDateFilter.startDate && exportDateFilter.endDate) {
            params.append('start_date', exportDateFilter.startDate);
            params.append('end_date', exportDateFilter.endDate);
        }
        
        params.append('limit', 1);
        params.append('skip', 0);
        
        const response = await fetch(`/admin/api/stores/list?${params.toString()}`, {
            headers: { 'Cache-Control': 'no-cache', 'Pragma': 'no-cache' }
        });
        
        const data = await response.json();
        const stores = data.stores || [];
        const store = stores.find(s => (s.store_name || '').toLowerCase() === storeName.toLowerCase());
        
        if (store) {
            // Remove if already exists (to avoid duplicates)
            const existingIndex = exportSelectedList.findIndex(s => (s.store_name || '').toLowerCase() === storeName.toLowerCase());
            if (existingIndex >= 0) {
                exportSelectedList.splice(existingIndex, 1);
            }
            // Add to top of preview table
            exportSelectedList.unshift(store);
            exportFilteredList = [...exportSelectedList];
            renderExportPreview();
            showToast(`Added "${store.store_name}" to export list`, 'success');
        }
    } catch (err) {
        console.error('Failed to add store:', err);
        showToast('Failed to add store', 'error');
    }
}

async function loadExportData(startDate = null, endDate = null) {
    try {
        showLoading();
        const params = new URLSearchParams();
        if (currentFilters.search) params.append('search', currentFilters.search);
        if (startDate) params.append('start_date', startDate);
        if (endDate) params.append('end_date', endDate);
        if (!startDate && currentFilters.start_date) params.append('start_date', currentFilters.start_date);
        if (!endDate && currentFilters.end_date) params.append('end_date', currentFilters.end_date);
        params.append('limit', 10000);
        params.append('skip', 0);
        const response = await fetch(`/admin/api/stores/list?${params.toString()}`, {
            headers: { 'Cache-Control': 'no-cache', 'Pragma': 'no-cache' }
        });
        const data = await response.json();
        exportStoreList = data.stores || [];
        exportSelectedList = [...exportStoreList];
        exportFilteredList = [...exportSelectedList];
        renderExportPreview();
    } catch (err) {
        console.error('Export load failed', err);
        document.getElementById('exportPreviewBody').innerHTML = '<tr><td colspan="3" style="text-align:center; padding:20px; color:#d32f2f;">Failed to load stores</td></tr>';
    } finally {
        hideLoading();
    }
}

function renderExportPreview() {
    const tbody = document.getElementById('exportPreviewBody');
    if (!exportFilteredList.length) {
        tbody.innerHTML = '<tr><td colspan="3" style="text-align:center; padding:20px;">No stores found</td></tr>';
        return;
    }
    tbody.innerHTML = exportFilteredList.map(store => `
        <tr>
            <td>${store.store_name || 'Unnamed Store'}</td>
            <td>${store.order_count || 0}</td>
            <td>₹${formatCurrency(store.total_revenue || 0)}</td>
        </tr>
    `).join('');
}

function renderExportSearchResults(searchResults) {
    const container = document.getElementById('exportSearchResults');
    
    if (!searchResults || searchResults.length === 0) {
        container.style.display = 'none';
        container.innerHTML = '';
        return;
    }

    const matches = searchResults.slice(0, 8);

    container.innerHTML = matches.map(store => {
        const safeName = encodeURIComponent(store.store_name || '');
        const isInPreview = exportSelectedList.some(s => (s.store_name || '').toLowerCase() === (store.store_name || '').toLowerCase());
        
        return `
            <div style="display:flex; align-items:center; justify-content:space-between; padding:10px 12px; border-bottom:1px solid #eef2f6; cursor:pointer; transition:background 0.2s;" onmouseenter="this.style.background='#f0f9ff'" onmouseleave="this.style.background='transparent'">
                <div>
                    <div style="font-weight:500; color:#1f2937; font-size:14px;">${store.store_name || 'Unnamed Store'}</div>
                    <div style="font-size:12px; color:#6b7280;">Orders: ${store.order_count || 0} | Revenue: ₹${formatCurrency(store.total_revenue || 0)}</div>
                </div>
                <button
                    data-store="${safeName}"
                    onclick="addStoreFromSearch(decodeURIComponent(this.dataset.store))"
                    style="padding:6px 12px; border:none; border-radius:6px; background:${isInPreview ? '#6b7280' : '#10b981'}; color:#fff; cursor:pointer; box-shadow:0 4px 10px rgba(16,185,129,0.2); font-weight:500;">
                    ${isInPreview ? 'Added' : 'Add'}
                </button>
            </div>
        `;
    }).join('');

    container.style.display = 'block';
}

async function downloadExportPDF() {
    if (!exportSelectedList.length) {
        showToast('Add at least one store to export', 'error');
        return;
    }
    await exportToPDF(exportSelectedList);
    closeExportModal();
}

// Open date range picker modal
function handleDateFilterChange() {
    const dateFilter = document.getElementById('dateFilter');
    const selectedValue = dateFilter.value;
    
    if (selectedValue === 'single') {
        const singleDateModal = document.getElementById('singleDateModal');
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
        
        // Set context to main (revenue management page)
        sessionStorage.setItem('dateFilterContext', 'main');
        singleDateModal.style.display = 'block';
    } else if (selectedValue === 'range') {
        // Set context to main (revenue management page) before opening
        sessionStorage.setItem('dateFilterContext', 'main');
        openRangeDateModal();
    } else if (selectedValue === 'all') {
        clearDateFilter();
    }
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
    
    // Clear context flag to prevent contamination between revenue and export workflows
    sessionStorage.removeItem('dateFilterContext');
    
    // Reset dropdown if user cancels
    if (selectedDateFilter.type === 'all') {
        document.getElementById('dateFilter').value = 'all';
    }
}

// Apply single date filter
function applySingleDate() {
    const datePicker = document.getElementById('singleDatePicker');
    const selectedDate = datePicker.value;
    const context = sessionStorage.getItem('dateFilterContext') || 'main';
    
    if (!selectedDate) {
        alert('Please select a date');
        return;
    }
    
    if (context === 'export') {
        // Apply to export date filter
        exportDateFilter.type = 'single';
        exportDateFilter.singleDate = selectedDate;
        exportDateFilter.startDate = null;
        exportDateFilter.endDate = null;
        
        // Update display
        const dateObj = new Date(selectedDate);
        const dateDisplay = dateObj.toLocaleDateString('en-US', { 
            year: 'numeric', 
            month: 'short', 
            day: 'numeric' 
        });
        document.getElementById('exportDateDisplay').textContent = dateDisplay;
        document.getElementById('exportDateDisplayGroup').style.display = 'block';
        
        // Reload export data with date filter
        loadExportData(selectedDate, selectedDate);
    } else {
        // Apply to main date filter
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
        
        filterStores();
    }
    
    closeDateModal();
    sessionStorage.removeItem('dateFilterContext');
}

// Apply date range filter
function applyDateRange() {
    const startPicker = document.getElementById('startDatePicker');
    const endPicker = document.getElementById('endDatePicker');
    const startDate = startPicker.value;
    const endDate = endPicker.value;
    const context = sessionStorage.getItem('dateFilterContext') || 'main';
    
    if (!startDate || !endDate) {
        alert('Please select both start and end dates');
        return;
    }
    
    if (new Date(startDate) > new Date(endDate)) {
        alert('Start date must be before or equal to end date');
        return;
    }
    
    if (context === 'export') {
        // Apply to export date filter
        exportDateFilter.type = 'range';
        exportDateFilter.singleDate = null;
        exportDateFilter.startDate = startDate;
        exportDateFilter.endDate = endDate;
        
        // Update display
        const startObj = new Date(startDate);
        const endObj = new Date(endDate);
        const dateDisplay = `${startObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} - ${endObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}`;
        document.getElementById('exportDateDisplay').textContent = dateDisplay;
        document.getElementById('exportDateDisplayGroup').style.display = 'block';
        
        // Reload export data with date filter
        loadExportData(startDate, endDate);
    } else {
        // Apply to main date filter
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
        
        filterStores();
    }
    
    closeDateModal();
    sessionStorage.removeItem('dateFilterContext');
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

// ============ PDF EXPORT FUNCTION ============
// Helper function to render Tamil text as image
async function renderTextAsImage(text, fontSize = 10) {
    return new Promise((resolve) => {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        
        // Set canvas size - adjusted for consistent sizing
        canvas.width = 300;
        canvas.height = 30;
        
        // Set font with Tamil support - matching PDF text size
        ctx.font = `${fontSize}px 'Noto Sans Tamil', Arial, sans-serif`;
        ctx.fillStyle = '#000000';
        ctx.textBaseline = 'middle';
        ctx.textAlign = 'left';
        
        // Draw text
        ctx.fillText(text, 2, 15);
        
        // Convert to data URL
        resolve(canvas.toDataURL('image/png'));
    });
}

async function exportToPDF() {
    try {
        // Show loading
        showLoading();
        
        // Accept pre-filtered list (from preview modal) or fetch if not provided
        let allStoresForExport = Array.isArray(arguments[0]) ? arguments[0] : null;
        if (!allStoresForExport || !allStoresForExport.length) {
            const params = new URLSearchParams();
            if (currentFilters.search) params.append('search', currentFilters.search);
            if (currentFilters.start_date) params.append('start_date', currentFilters.start_date);
            if (currentFilters.end_date) params.append('end_date', currentFilters.end_date);
            params.append('limit', 10000);
            params.append('skip', 0);
            
            const response = await fetch(`/admin/api/stores/list?${params.toString()}`, {
                headers: {
                    'Cache-Control': 'no-cache',
                    'Pragma': 'no-cache'
                }
            });
            
            if (!response.ok) {
                throw new Error(`Failed to fetch stores: ${response.status}`);
            }
            
            const data = await response.json();
            allStoresForExport = data.stores || [];
            exportStoreList = allStoresForExport;
            exportFilteredList = [...exportStoreList];
        }
        
        // Get jsPDF from global
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF();
        
        // Get current statistics
        const totalStores = document.getElementById('totalStores').textContent;
        const totalOrders = document.getElementById('totalOrders').textContent;
        const totalRevenue = document.getElementById('totalRevenue').textContent.replace(/₹/g, 'Rs.');
        const avgPerStore = document.getElementById('avgPerStore').textContent.replace(/₹/g, 'Rs.');
        
        // Set document properties
        doc.setProperties({
            title: 'Revenue Management Report',
            subject: 'Store Revenue Report',
            author: 'AL-Madhina Admin',
            keywords: 'revenue, stores, orders',
            creator: 'AL-Madhina System'
        });
        
        // Add AL-Madhina branding at top
        doc.setFontSize(24);
        doc.setTextColor(40, 167, 69); // Green color
        doc.text('Al-Mathina', 14, 15);
        
        // Add header
        doc.setFontSize(18);
        doc.setTextColor(40, 167, 69);
        doc.text('Revenue Management Report', 14, 25);
        
        // Add date
        doc.setFontSize(10);
        doc.setTextColor(100);
        const today = new Date().toLocaleDateString('en-US', { 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric' 
        });
        doc.text(`Generated: ${today}`, 14, 32);
        
        // Add filter information
        let yPos = 40;
        if (currentFilters.search) {
            doc.text(`Search Filter: ${currentFilters.search}`, 14, yPos);
            yPos += 5;
        }
        if (currentFilters.start_date && currentFilters.end_date) {
            const startDate = new Date(currentFilters.start_date).toLocaleDateString('en-US', {
                year: 'numeric', month: 'short', day: 'numeric'
            });
            const endDate = new Date(currentFilters.end_date).toLocaleDateString('en-US', {
                year: 'numeric', month: 'short', day: 'numeric'
            });
            doc.text(`Date Range: ${startDate} - ${endDate}`, 14, yPos);
            yPos += 5;
        } else if (currentFilters.start_date) {
            const singleDate = new Date(currentFilters.start_date).toLocaleDateString('en-US', {
                year: 'numeric', month: 'short', day: 'numeric'
            });
            doc.text(`Date: ${singleDate}`, 14, yPos);
            yPos += 5;
        }
        
        yPos += 5;
        
        // Add summary statistics
        doc.setFontSize(12);
        doc.setTextColor(0);
        doc.text('Summary Statistics', 14, yPos);
        yPos += 7;
        
        doc.setFontSize(10);
        const stats = [
            ['Total Stores', totalStores],
            ['Total Orders', totalOrders],
            ['Total Revenue', totalRevenue],
            ['Average per Store', avgPerStore]
        ];
        
        doc.autoTable({
            startY: yPos,
            head: [['Metric', 'Value']],
            body: stats,
            theme: 'grid',
            headStyles: { fillColor: [40, 167, 69] },
            margin: { left: 14, right: 14 },
            styles: { font: 'helvetica', fontSize: 10 }
        });
        
        yPos = doc.lastAutoTable.finalY + 10;
        
        // Add store details header
        doc.setFontSize(12);
        doc.text('Store Details', 14, yPos);
        yPos += 7;
        
        // Render stores with Tamil support using images
        doc.setFontSize(10);
        doc.setTextColor(0);
        
        // Table header
        doc.setFillColor(40, 167, 69);
        doc.rect(14, yPos, 200, 8, 'F');
        doc.setTextColor(255, 255, 255);
        doc.text('Store Name', 16, yPos + 5);
        doc.text('Orders', 120, yPos + 5);
        doc.text('Revenue', 160, yPos + 5);
        yPos += 8;
        
        // Add stores one by one
        doc.setTextColor(0);
        let rowColor = true;
        
        for (let i = 0; i < allStoresForExport.length; i++) {
            const store = allStoresForExport[i];
            const storeName = store.store_name || 'Unnamed Store';
            const hasTamil = /[\u0B80-\u0BFF]/.test(storeName);
            
            // Check if we need a new page
            if (yPos > 270) {
                doc.addPage();
                yPos = 20;
                
                // Re-add header on new page
                doc.setFillColor(40, 167, 69);
                doc.rect(14, yPos, 200, 8, 'F');
                doc.setTextColor(255, 255, 255);
                doc.text('Store Name', 16, yPos + 5);
                doc.text('Orders', 120, yPos + 5);
                doc.text('Revenue', 160, yPos + 5);
                yPos += 8;
                doc.setTextColor(0);
                rowColor = true;
            }
            
            // Alternate row background
            if (rowColor) {
                doc.setFillColor(245, 245, 245);
                doc.rect(14, yPos, 200, 10, 'F');
            }
            rowColor = !rowColor;
            
            // Add store name (as image if Tamil, as text if English)
            if (hasTamil) {
                const imgData = await renderTextAsImage(storeName, 10);
                doc.addImage(imgData, 'PNG', 16, yPos + 2, 80, 6);
            } else {
                doc.text(storeName, 16, yPos + 6);
            }
            
            // Add orders and revenue
            doc.text(store.order_count.toString(), 120, yPos + 6);
            doc.text(`Rs.${formatCurrency(store.total_revenue)}`, 160, yPos + 6);
            
            yPos += 10;
        }
        
        // Add footer with page numbers
        const pageCount = doc.internal.getNumberOfPages();
        for (let i = 1; i <= pageCount; i++) {
            doc.setPage(i);
            doc.setFontSize(8);
            doc.setTextColor(150);
            doc.text(
                `Page ${i} of ${pageCount}`,
                doc.internal.pageSize.getWidth() / 2,
                doc.internal.pageSize.getHeight() - 10,
                { align: 'center' }
            );
        }
        
        // Generate filename
        const filename = `revenue-report-${new Date().toISOString().split('T')[0]}.pdf`;
        
        hideLoading();
        
        // Save the PDF
        doc.save(filename);
        
        // Show success message
        showToast('PDF exported successfully!', 'success');
        
        // Optionally show WhatsApp share dialog
        setTimeout(() => {
            if (confirm('PDF downloaded! Would you like to share it via WhatsApp?')) {
                shareViaWhatsApp(doc, filename);
            }
        }, 500);
        
    } catch (error) {
        console.error('Error exporting PDF:', error);
        hideLoading();
        showToast('Failed to export PDF', 'error');
    }
}

// Share PDF via WhatsApp
function shareViaWhatsApp(doc, filename) {
    try {
        // Convert PDF to blob
        const pdfBlob = doc.output('blob');
        
        // Check if Web Share API is supported
        if (navigator.share && navigator.canShare && navigator.canShare({ files: [new File([pdfBlob], filename, { type: 'application/pdf' })] })) {
            const file = new File([pdfBlob], filename, { type: 'application/pdf' });
            
            navigator.share({
                title: 'Revenue Management Report',
                text: 'Store revenue and order statistics',
                files: [file]
            })
            .then(() => console.log('Shared successfully'))
            .catch((error) => {
                console.log('Share cancelled or failed:', error);
                fallbackWhatsAppShare();
            });
        } else {
            // Fallback: WhatsApp Web with text message
            fallbackWhatsAppShare();
        }
    } catch (error) {
        console.error('Error sharing via WhatsApp:', error);
        fallbackWhatsAppShare();
    }
}

// Fallback WhatsApp share (opens WhatsApp with text message)
function fallbackWhatsAppShare() {
    const message = encodeURIComponent(
        `*Al-Mathina*\n` +
        `Revenue Management Report\n\n` +
        `Total Stores: ${document.getElementById('totalStores').textContent}\n` +
        `Total Orders: ${document.getElementById('totalOrders').textContent}\n` +
        `Total Revenue: ${document.getElementById('totalRevenue').textContent}\n` +
        `Average per Store: ${document.getElementById('avgPerStore').textContent}\n\n` +
        `Generated: ${new Date().toLocaleDateString('en-IN')}\n\n` +
        `(Full PDF report has been downloaded to your device)`
    );
    
    const whatsappUrl = `https://wa.me/?text=${message}`;
    window.open(whatsappUrl, '_blank');
}

// ============ END PDF EXPORT FUNCTION ============

// ============ ORDER DETAILS MODAL ============
// View order details in modal
async function viewOrderDetails(orderId) {
    try {
        const modal = document.getElementById('orderDetailsModal');
        const content = document.getElementById('orderDetailsContent');
        
        if (!content) {
            console.error('orderDetailsContent element not found');
            return;
        }
        
        // Show loading state
        content.innerHTML = `
            <div class="modal-body" style="text-align: center; padding: 40px;">
                <div class="spinner" style="margin: 0 auto 20px;"></div>
                <p>Loading order details...</p>
            </div>
        `;
        modal.style.display = 'flex';
        
        // Fetch order details
        const response = await fetch(`/api/admin/orders/${orderId}`);
        const data = await response.json();
        
        if (data.success) {
            showOrderDetailsContent(data.order);
        } else {
            content.innerHTML = `
                <div class="modal-body" style="text-align: center; padding: 40px;">
                    <i class="fas fa-exclamation-triangle" style="font-size: 48px; color: #f44336; margin-bottom: 20px;"></i>
                    <h3>Error</h3>
                    <p>Failed to load order details</p>
                </div>
            `;
        }
    } catch (error) {
        console.error('Error loading order details:', error);
        const content = document.getElementById('orderDetailsContent');
        if (content) {
            content.innerHTML = `
                <div class="modal-body" style="text-align: center; padding: 40px;">
                    <i class="fas fa-exclamation-triangle" style="font-size: 48px; color: #f44336; margin-bottom: 20px;"></i>
                    <h3>Error</h3>
                    <p>Error loading order details: ${error.message}</p>
                </div>
            `;
        }
    }
}

// Delete user profile with confirmation
async function deleteUserProfile(phone, storeName) {
    // Show confirmation dialog
    const confirmed = confirm(
        `⚠️ DELETE USER PROFILE\n\n` +
        `Store: ${storeName}\n` +
        `Phone: ${phone}\n\n` +
        `This will permanently delete:\n` +
        `• User profile\n` +
        `• All orders\n` +
        `• Store details\n` +
        `• FCM tokens\n\n` +
        `This action CANNOT be undone!\n\n` +
        `Are you sure you want to delete this user?`
    );
    
    if (!confirmed) {
        return;
    }
    
    try {
        showLoading();
        
        const response = await fetch(`/api/flutter/user/profile/${phone}`, {
            method: 'DELETE'
        });
        
        const data = await response.json();
        
        if (response.ok && data.success) {
            // Show success message
            alert(
                `✅ User Deleted Successfully\n\n` +
                `Phone: ${phone}\n` +
                `Store: ${data.deleted.store_name}\n` +
                `Orders Deleted: ${data.deleted.orders_deleted}\n\n` +
                `The user profile has been permanently removed.`
            );
            
            // Reload stores list
            loadStores(true);
        } else {
            alert(`❌ Error: ${data.detail || 'Failed to delete user profile'}`);
        }
    } catch (error) {
        console.error('Error deleting user profile:', error);
        alert(`❌ Error deleting user profile: ${error.message}`);
    } finally {
        hideLoading();
    }
}

// Show order details content
function showOrderDetailsContent(order) {
    const content = document.getElementById('orderDetailsContent');
    
    content.innerHTML = `
        <div class="modal-body">
            <div class="order-details-header" style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 30px; padding-bottom: 20px; border-bottom: 2px solid #e0e0e0;">
                <div>
                    <h2 style="margin: 0 0 10px 0; color: #1B5E20;">Order #${order.order_id}</h2>
                    <p style="margin: 0; color: #666; font-size: 14px;">${formatDateTime(order.created_at)}</p>
                </div>
                <span class="status-badge status-${order.status}" style="padding: 8px 16px; border-radius: 20px; font-weight: 600; font-size: 13px; text-transform: uppercase;">
                    ${order.status}
                </span>
            </div>
            
            <div class="order-sections" style="display: grid; gap: 25px;">
                <!-- Customer Information -->
                <div class="detail-section" style="background: #f9f9f9; padding: 20px; border-radius: 8px;">
                    <h3 style="margin: 0 0 15px 0; color: #1B5E20; font-size: 16px; display: flex; align-items: center; gap: 8px;">
                        <i class="fas fa-user-circle"></i> Customer Information
                    </h3>
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px;">
                        <div>
                            <label style="display: block; color: #666; font-size: 13px; margin-bottom: 5px;">Name</label>
                            <span style="font-weight: 600;">${order.user_name || 'Unknown'}</span>
                        </div>
                        <div>
                            <label style="display: block; color: #666; font-size: 13px; margin-bottom: 5px;">Phone</label>
                            <span style="font-weight: 600;">${order.user_phone}</span>
                        </div>
                        ${order.user_store_name ? `
                            <div>
                                <label style="display: block; color: #666; font-size: 13px; margin-bottom: 5px;">Store Name</label>
                                <span style="font-weight: 600;">${order.user_store_name}</span>
                            </div>
                        ` : ''}
                    </div>
                </div>
                
                <!-- Delivery Address -->
                ${order.user_store_address && (order.user_store_address.street || order.user_store_address.city) ? `
                    <div class="detail-section" style="background: #f9f9f9; padding: 20px; border-radius: 8px;">
                        <h3 style="margin: 0 0 15px 0; color: #1B5E20; font-size: 16px; display: flex; align-items: center; gap: 8px;">
                            <i class="fas fa-map-marker-alt"></i> Delivery Address
                        </h3>
                        <div style="line-height: 1.6; color: #333;">
                            ${order.user_store_address.street || ''}<br>
                            ${order.user_store_address.city || ''}, ${order.user_store_address.state || ''} - ${order.user_store_address.pincode || ''}
                            ${order.user_store_address.landmark ? `<br>Landmark: ${order.user_store_address.landmark}` : ''}
                        </div>
                    </div>
                ` : order.delivery_address && (order.delivery_address.street || order.delivery_address.city) ? `
                    <div class="detail-section" style="background: #f9f9f9; padding: 20px; border-radius: 8px;">
                        <h3 style="margin: 0 0 15px 0; color: #1B5E20; font-size: 16px; display: flex; align-items: center; gap: 8px;">
                            <i class="fas fa-map-marker-alt"></i> Delivery Address
                        </h3>
                        <div style="line-height: 1.6; color: #333;">
                            ${order.delivery_address.street || ''}<br>
                            ${order.delivery_address.city || ''}, ${order.delivery_address.state || ''} - ${order.delivery_address.pincode || ''}
                            ${order.delivery_address.landmark ? `<br>Landmark: ${order.delivery_address.landmark}` : ''}
                        </div>
                    </div>
                ` : ''}
                
                <!-- Order Items -->
                <div class="detail-section" style="background: #f9f9f9; padding: 20px; border-radius: 8px;">
                    <h3 style="margin: 0 0 15px 0; color: #1B5E20; font-size: 16px; display: flex; align-items: center; gap: 8px;">
                        <i class="fas fa-box-open"></i> Order Items (${order.items.length})
                    </h3>
                    <div style="overflow-x: auto;">
                        <table style="width: 100%; border-collapse: collapse;">
                            <thead>
                                <tr style="background: #fff; border-bottom: 2px solid #4CAF50;">
                                    <th style="padding: 12px; text-align: left; font-size: 13px; color: #1B5E20;">Product</th>
                                    <th style="padding: 12px; text-align: center; font-size: 13px; color: #1B5E20;">Weight</th>
                                    <th style="padding: 12px; text-align: right; font-size: 13px; color: #1B5E20;">Price</th>
                                    <th style="padding: 12px; text-align: center; font-size: 13px; color: #1B5E20;">Qty</th>
                                    <th style="padding: 12px; text-align: right; font-size: 13px; color: #1B5E20;">Total</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${order.items.map(item => `
                                    <tr style="border-bottom: 1px solid #e0e0e0;">
                                        <td style="padding: 12px;"><strong>${item.product_name}</strong></td>
                                        <td style="padding: 12px; text-align: center;">${item.weight || '-'}</td>
                                        <td style="padding: 12px; text-align: right;">₹${parseFloat(item.price).toFixed(2)}</td>
                                        <td style="padding: 12px; text-align: center;">×${item.quantity}</td>
                                        <td style="padding: 12px; text-align: right;"><strong>₹${(item.price * item.quantity).toFixed(2)}</strong></td>
                                    </tr>
                                `).join('')}
                            </tbody>
                            <tfoot>
                                <tr style="background: #fff; border-top: 2px solid #4CAF50;">
                                    <td colspan="4" style="padding: 15px; text-align: right; font-weight: 600; color: #1B5E20;">Grand Total:</td>
                                    <td style="padding: 15px; text-align: right; font-size: 18px; font-weight: 700; color: #4CAF50;">₹${parseFloat(order.total_amount).toFixed(2)}</td>
                                </tr>
                            </tfoot>
                        </table>
                    </div>
                </div>
                
                <!-- Payment & Status -->
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px;">
                    <div class="detail-section" style="background: #f9f9f9; padding: 20px; border-radius: 8px;">
                        <h3 style="margin: 0 0 10px 0; color: #1B5E20; font-size: 14px; display: flex; align-items: center; gap: 8px;">
                            <i class="fas fa-credit-card"></i> Payment
                        </h3>
                        <p style="margin: 0; font-weight: 600;">${order.payment_method || 'Cash on Delivery'}</p>
                    </div>
                    <div class="detail-section" style="background: #f9f9f9; padding: 20px; border-radius: 8px;">
                        <h3 style="margin: 0 0 10px 0; color: #1B5E20; font-size: 14px; display: flex; align-items: center; gap: 8px;">
                            <i class="fas fa-info-circle"></i> Status
                        </h3>
                        <p style="margin: 0; font-weight: 600; text-transform: capitalize;">${order.status}</p>
                    </div>
                </div>
            </div>
            
            <div style="margin-top: 30px; text-align: right; padding-top: 20px; border-top: 2px solid #e0e0e0;">
                <button onclick="closeOrderDetailsModal()" class="btn btn-secondary" style="padding: 12px 30px; font-size: 15px;">
                    <i class="fas fa-times"></i> Close
                </button>
            </div>
        </div>
    `;
}

// Close order details modal
function closeOrderDetailsModal() {
    const modal = document.getElementById('orderDetailsModal');
    if (modal) {
        modal.style.display = 'none';
    }
}

// ============ END ORDER DETAILS MODAL ============

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
