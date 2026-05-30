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

// Quick filter state
let currentQuickFilter = 'all'; // 'all', 'daily', 'monthly', 'yearly'

// Header scroll behavior state
let lastScrollTop = 0;
let scrollTimeout;

// Initialize page
document.addEventListener('DOMContentLoaded', () => {
    loadStores(true);
    setupScrollListener();
    setupHeaderScrollBehavior();
    updateMonthSummaryButtonText();
});

// Update month summary button with current month name
function updateMonthSummaryButtonText() {
    const now = new Date();
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
    const currentMonth = monthNames[now.getMonth()];
    const monthSummaryText = document.getElementById('monthSummaryText');
    if (monthSummaryText) {
        monthSummaryText.textContent = currentMonth + ' Summary';
    }
}

// Apply quick date filter (Daily, Monthly, Yearly)
function applyQuickDateFilter(filterType) {
    console.log('📅 Quick Date Filter Applied:', filterType);

    // Update active button state
    document.querySelectorAll('.quick-filter-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    document.querySelector(`[data-filter="${filterType}"]`).classList.add('active');

    // Store current filter
    currentQuickFilter = filterType;

    const now = new Date();
    let startDate = null;
    let endDate = null;

    if (filterType === 'all') {
        // All time - no date filters
        currentFilters.start_date = '';
        currentFilters.end_date = '';
        selectedDateFilter.type = 'all';

        // Reset date filter dropdown
        document.getElementById('dateFilter').value = 'all';
        document.getElementById('dateDisplayGroup').style.display = 'none';

    } else if (filterType === 'daily') {
        // Today only
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

    } else if (filterType === 'monthly') {
        // Current month
        startDate = new Date(now.getFullYear(), now.getMonth(), 1);
        endDate = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

    } else if (filterType === 'yearly') {
        // Current year
        startDate = new Date(now.getFullYear(), 0, 1);
        endDate = new Date(now.getFullYear(), 11, 31, 23, 59, 59);
    }

    if (startDate && endDate) {
        // Format dates for API (YYYY-MM-DD)
        const formatDate = (date) => {
            const year = date.getFullYear();
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const day = String(date.getDate()).padStart(2, '0');
            return `${year}-${month}-${day}`;
        };

        currentFilters.start_date = formatDate(startDate);
        currentFilters.end_date = formatDate(endDate);

        // Update selected date filter state
        selectedDateFilter.type = 'range';
        selectedDateFilter.startDate = startDate;
        selectedDateFilter.endDate = endDate;

        // Update date filter dropdown to show range
        document.getElementById('dateFilter').value = 'range';

        // Show date display
        const dateDisplay = document.getElementById('dateDisplay');
        const dateDisplayGroup = document.getElementById('dateDisplayGroup');

        if (filterType === 'daily') {
            dateDisplay.textContent = `Today: ${startDate.toLocaleDateString('en-IN')}`;
        } else if (filterType === 'monthly') {
            dateDisplay.textContent = `This Month: ${startDate.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' })}`;
        } else if (filterType === 'yearly') {
            dateDisplay.textContent = `This Year: ${startDate.getFullYear()}`;
        }

        dateDisplayGroup.style.display = 'block';
    }

    console.log('📅 Date Range Set:', {
        start: currentFilters.start_date,
        end: currentFilters.end_date,
        type: filterType
    });

    // Reload stores with new date filter
    loadStores(true);
}

// ============ SUMMARY SELECTOR FUNCTIONS ============

function showSummaryMenu() {
    document.getElementById('summaryTypeModal').style.display = 'flex';
}

function closeSummaryTypeModal() {
    document.getElementById('summaryTypeModal').style.display = 'none';
}

// Daily Date Picker - Show dates with today highlighted
function showDailyDatePicker() {
    closeSummaryTypeModal();
    const modal = document.getElementById('dailyDateModal');
    const grid = document.getElementById('dailyDatesGrid');

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const currentDay = today.getDate();
    const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();

    grid.innerHTML = '';

    // Show dates from 1 to today (not future dates)
    const lastDayToShow = Math.min(currentDay, daysInMonth);

    for (let day = 1; day <= lastDayToShow; day++) {
        const date = new Date(now.getFullYear(), now.getMonth(), day);
        const btn = document.createElement('button');
        btn.className = 'date-selector-btn';
        btn.textContent = day;

        // Highlight today's date
        if (day === currentDay) {
            btn.style.backgroundColor = '#2196F3';
            btn.style.color = 'white';
            btn.style.fontWeight = '700';
        }

        btn.onclick = () => {
            const dateStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
            applyDailyFilter(dateStr);
            closeDailyDateModal();
        };
        grid.appendChild(btn);
    }

    modal.style.display = 'flex';
}

function closeDailyDateModal() {
    document.getElementById('dailyDateModal').style.display = 'none';
}

function applyDailyFilter(dateStr) {
    currentFilters.start_date = dateStr;
    currentFilters.end_date = dateStr;
    currentQuickFilter = 'daily';

    // Update date display
    const dateObj = new Date(dateStr);
    const dateDisplay = dateObj.toLocaleDateString('en-IN', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
    document.getElementById('dateDisplay').textContent = dateDisplay;
    document.getElementById('dateDisplayGroup').style.display = 'block';

    loadStores(true);
    showToast(`📅 Showing data for ${dateDisplay}`);
}

// Weekly Selector - Show weeks with current week highlighted
function showWeeklySelector() {
    closeSummaryTypeModal();
    const modal = document.getElementById('weeklyModal');
    const container = document.getElementById('weeklyWeeksContainer');

    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const currentDay = now.getDate();

    // Calculate current week
    const currentWeekNum = Math.ceil(currentDay / 7);

    const weeks = [];
    let weekStart = 1;

    while (weekStart <= daysInMonth) {
        const weekEnd = Math.min(weekStart + 6, daysInMonth);
        weeks.push({ start: weekStart, end: weekEnd });
        weekStart += 7;
    }

    container.innerHTML = '';

    weeks.forEach((week, index) => {
        const btn = document.createElement('button');
        btn.className = 'week-selector-btn';

        // Highlight current week
        if (index + 1 === currentWeekNum) {
            btn.style.backgroundColor = '#2196F3';
            btn.style.color = 'white';
            btn.style.fontWeight = '700';
        }

        btn.innerHTML = `
            <div style="font-weight: 600;">Week ${index + 1}</div>
            <div style="font-size: 12px; ${index + 1 === currentWeekNum ? 'color: white;' : 'color: #666;'}">
                ${week.start} - ${week.end} ${new Intl.DateTimeFormat('en-US', { month: 'short' }).format(now)}
            </div>
        `;
        btn.onclick = () => {
            const startStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(week.start).padStart(2, '0')}`;
            const endStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(week.end).padStart(2, '0')}`;
            applyWeeklyFilter(startStr, endStr, index + 1);
            closeWeeklyModal();
        };
        container.appendChild(btn);
    });

    modal.style.display = 'flex';
}

function closeWeeklyModal() {
    document.getElementById('weeklyModal').style.display = 'none';
}

function applyWeeklyFilter(startDate, endDate, weekNum) {
    currentFilters.start_date = startDate;
    currentFilters.end_date = endDate;
    currentQuickFilter = 'weekly';

    // Update date display
    const dateObj = new Date(startDate);
    const monthName = dateObj.toLocaleDateString('en-US', { month: 'short' });
    const startDay = new Date(startDate).getDate();
    const endDay = new Date(endDate).getDate();
    const dateDisplay = `Week ${weekNum}: ${startDay} - ${endDay} ${monthName}`;
    document.getElementById('dateDisplay').textContent = dateDisplay;
    document.getElementById('dateDisplayGroup').style.display = 'block';

    loadStores(true);
    showToast(`📅 Showing data for Week ${weekNum}`);
}

// Monthly Selector - Show months with current month highlighted
function showMonthlySelector() {
    closeSummaryTypeModal();
    const modal = document.getElementById('monthlyModal');
    const grid = document.getElementById('monthlyMonthsGrid');

    const now = new Date();
    const year = now.getFullYear();
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];

    grid.innerHTML = '';

    monthNames.forEach((monthName, monthIndex) => {
        const btn = document.createElement('button');
        btn.className = 'month-selector-btn';

        // Highlight current month
        if (monthIndex === now.getMonth()) {
            btn.style.backgroundColor = '#2196F3';
            btn.style.color = 'white';
            btn.style.fontWeight = '700';
        }

        btn.textContent = monthName.substring(0, 3);
        btn.onclick = () => {
            const startStr = `${year}-${String(monthIndex + 1).padStart(2, '0')}-01`;
            const daysInMonth = new Date(year, monthIndex + 1, 0).getDate();
            const endStr = `${year}-${String(monthIndex + 1).padStart(2, '0')}-${daysInMonth}`;
            applyMonthlyFilter(startStr, endStr, monthName);
            closeMonthlyModal();
        };
        grid.appendChild(btn);
    });

    modal.style.display = 'flex';
}

function closeMonthlyModal() {
    document.getElementById('monthlyModal').style.display = 'none';
}

function applyMonthlyFilter(startDate, endDate, monthName) {
    currentFilters.start_date = startDate;
    currentFilters.end_date = endDate;
    currentQuickFilter = 'monthly';

    // Update date display
    const year = new Date(startDate).getFullYear();
    const dateDisplay = `This Month: ${monthName}`;
    document.getElementById('dateDisplay').textContent = dateDisplay;
    document.getElementById('dateDisplayGroup').style.display = 'block';

    loadStores(true);
    showToast(`📅 Showing data for ${monthName}`);
}

// Yearly Selector - Let user choose year
function showYearlySelector() {
    closeSummaryTypeModal();
    const modal = document.getElementById('yearlyModal');
    const grid = document.getElementById('yearlyYearsGrid');

    const now = new Date();
    const currentYear = now.getFullYear();
    const startYear = 2020;

    grid.innerHTML = '';

    for (let year = currentYear; year >= startYear; year--) {
        const btn = document.createElement('button');
        btn.className = 'year-selector-btn';
        if (year === currentYear) {
            btn.style.backgroundColor = '#2196F3';
            btn.style.color = 'white';
        }
        if (year > currentYear) {
            btn.disabled = true;
            btn.style.opacity = '0.5';
            btn.style.cursor = 'not-allowed';
        }
        btn.textContent = year;
        btn.onclick = () => {
            if (year <= currentYear) {
                applyYearlyFilter(year);
                closeYearlyModal();
            }
        };
        grid.appendChild(btn);
    }

    modal.style.display = 'flex';
}

function closeYearlyModal() {
    document.getElementById('yearlyModal').style.display = 'none';
}

function applyYearlyFilter(year) {
    const startStr = `${year}-01-01`;
    const endStr = `${year}-12-31`;
    currentFilters.start_date = startStr;
    currentFilters.end_date = endStr;
    currentQuickFilter = 'yearly';

    // Update date display
    const dateDisplay = `This Year: ${year}`;
    document.getElementById('dateDisplay').textContent = dateDisplay;
    document.getElementById('dateDisplayGroup').style.display = 'block';

    loadStores(true);
    showToast(`📅 Showing data for ${year}`);
}

// All Time Filter
function applyAllTimeFilter() {
    closeSummaryTypeModal();
    currentFilters.start_date = '';
    currentFilters.end_date = '';
    currentQuickFilter = 'all';
    loadStores(true);
    showToast('📅 Showing all time data');
}

// Helper function to show toast (if not exists)
function showToast(message) {
    console.log(message);
    // Optional: Add actual toast notification
}

// Close modals when clicking outside
window.addEventListener('click', (e) => {
    // Summary modals
    if (e.target.id === 'summaryTypeModal') closeSummaryTypeModal();
    if (e.target.id === 'dailyDateModal') closeDailyDateModal();
    if (e.target.id === 'weeklyModal') closeWeeklyModal();
    if (e.target.id === 'monthlyModal') closeMonthlyModal();
    if (e.target.id === 'yearlyModal') closeYearlyModal();
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
                <div class="store-card-payment">
                    <div class="payment-stat">
                        <i class="fas fa-file-invoice-dollar"></i>
                        <span class="payment-label">Due:</span>
                        <span class="payment-value total">₹${formatCurrency(store.all_time_due || 0)}</span>
                    </div>
                    <div class="payment-stat">
                        <i class="fas fa-wallet"></i>
                        <span class="payment-label">Paid:</span>
                        <span class="payment-value paid">₹${formatCurrency(store.all_time_paid || 0)}</span>
                    </div>
                    <div class="payment-stat">
                        <i class="fas fa-hourglass-half"></i>
                        <span class="payment-label">Balance:</span>
                        <span class="payment-value balance">₹${formatCurrency(store.all_time_balance || 0)}</span>
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
    const store = data?.store || {};
    const revenue = data?.revenue || {};
    const orders = Array.isArray(data?.orders) ? data.orders : [];

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

    // Payment tracking - ALL-TIME totals (independent of date filter)
    const allTimeDue = store.all_time_due || 0;
    const allTimePaid = store.all_time_paid || 0;
    const allTimeBalance = store.all_time_balance || 0;

    document.getElementById('detailTotalDue').textContent = `₹${formatCurrency(allTimeDue)}`;
    document.getElementById('detailBalance').textContent = `₹${formatCurrency(allTimeBalance)}`;

    // Store payment values for editing
    currentStoreDetail.totalDue = allTimeDue;
    currentStoreDetail.totalPaid = allTimePaid;

    // Render payment history in modal
    renderPaymentHistory();

    // Orders
    displayStoreOrders(orders);
}

// Display store orders as slim cards
function displayStoreOrders(orders) {
    const container = document.getElementById('storeOrders');
    const safeOrders = Array.isArray(orders) ? orders : [];

    if (safeOrders.length === 0) {
        container.innerHTML = `
            <div class="empty-orders">
                <i class="fas fa-inbox"></i>
                <p>No orders found</p>
            </div>
        `;
        return;
    }

    container.innerHTML = safeOrders.map(order => {
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

// Payment history modal
function showPaymentHistory() {
    renderPaymentHistory();
    document.getElementById('paymentHistoryModal').style.display = 'flex';
}

function closePaymentHistory() {
    document.getElementById('paymentHistoryModal').style.display = 'none';
}

function renderPaymentHistory() {
    const tbody = document.getElementById('paymentHistoryTableBody');
    if (!tbody) return;
    const history = currentStoreDetail?.store?.payment_history || [];

    if (!history.length) {
        tbody.innerHTML = '<tr><td colspan="3" style="text-align:center; padding:20px; color:#9ca3af;"><i class="fas fa-inbox"></i> No payment history yet</td></tr>';
        return;
    }

    const sorted = [...history].sort((a, b) => new Date(b.timestamp || 0) - new Date(a.timestamp || 0));
    tbody.innerHTML = sorted.map((entry, index) => {
        const amount = formatCurrency(entry.amount || 0);
        // Format date without time
        const date = entry.timestamp ? new Date(entry.timestamp).toLocaleDateString('en-IN', {
            year: 'numeric',
            month: 'short',
            day: '2-digit'
        }) : 'N/A';
        return `
            <tr>
                <td>₹${amount}</td>
                <td>${date}</td>
                <td style="text-align:center;">
                    <button onclick="removePayment('${entry.timestamp}', ${entry.amount})" 
                            class="btn-remove-payment" 
                            title="Remove this payment">
                        <i class="fas fa-times"></i> Remove
                    </button>
                </td>
            </tr>
        `;
    }).join('');
}

// Close modals on outside click
window.onclick = function (event) {
    const storeModal = document.getElementById('storeDetailModal');
    const revenueModal = document.getElementById('revenueModal');
    const paymentHistoryModal = document.getElementById('paymentHistoryModal');

    if (event.target === storeModal) {
        closeStoreDetail();
    }
    if (event.target === revenueModal) {
        closeRevenueModal();
    }
    if (event.target === paymentHistoryModal) {
        closePaymentHistory();
    }
};

// Edit paid amount
function editPaidAmount() {
    if (!currentStoreDetail) return;

    const currentBalance = currentStoreDetail.totalDue - currentStoreDetail.totalPaid;
    const paymentAmount = prompt(`Enter payment amount to add:\n\nBalance: ₹${formatCurrency(currentBalance)}\nTotal Due: ₹${formatCurrency(currentStoreDetail.totalDue)}`, '');

    if (paymentAmount === null) return; // User cancelled

    const amount = parseFloat(paymentAmount);

    if (isNaN(amount) || amount <= 0) {
        showToast('Please enter a valid positive number', 'error');
        return;
    }

    const newTotalPaid = (currentStoreDetail.totalPaid || 0) + amount;

    if (newTotalPaid > currentStoreDetail.totalDue) {
        if (!confirm(`Payment (₹${formatCurrency(amount)}) will exceed total due.\n\nNew total paid will be: ₹${formatCurrency(newTotalPaid)}\nTotal due: ₹${formatCurrency(currentStoreDetail.totalDue)}\n\nContinue anyway?`)) {
            return;
        }
    }

    appendPayment(amount);
}

// Remove payment from history
async function removePayment(timestamp, amount) {
    if (!currentStoreDetail || !currentStoreDetail.store) return;

    if (!confirm(`Remove payment of ₹${formatCurrency(amount)}?\n\nThis will add ₹${formatCurrency(amount)} back to the balance.`)) {
        return;
    }

    try {
        showLoading();

        const phone = currentStoreDetail.store.phone;

        console.group('%c❌ Payment Remove - Request', 'color:#ef4444; font-weight:bold;');
        console.log('Removing payment:', { phone, timestamp, amount });
        console.groupEnd();

        const response = await fetch(`/admin/api/stores/${phone}/payment-history/${encodeURIComponent(timestamp)}`, {
            method: 'DELETE',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        if (!response.ok) {
            const data = await response.json();
            throw new Error(data.error || 'Failed to remove payment');
        }

        const data = await response.json();
        console.group('%c✅ Payment Remove - Response', 'color:#22c55e; font-weight:bold;');
        console.log('Response:', data);
        console.groupEnd();

        // Update local state
        const newTotalPaid = Math.max(0, (currentStoreDetail.totalPaid || 0) - amount);
        currentStoreDetail.totalPaid = newTotalPaid;
        currentStoreDetail.store.total_paid = newTotalPaid;
        currentStoreDetail.store.all_time_paid = newTotalPaid;

        // Remove from payment history array
        if (currentStoreDetail.store.payment_history) {
            currentStoreDetail.store.payment_history = currentStoreDetail.store.payment_history.filter(
                p => p.timestamp !== timestamp
            );
        }

        // Update display
        const balance = currentStoreDetail.totalDue - newTotalPaid;
        currentStoreDetail.store.all_time_balance = balance;
        document.getElementById('detailBalance').textContent = `₹${formatCurrency(balance)}`;
        renderPaymentHistory();

        showToast(`Payment of ₹${formatCurrency(amount)} removed - Balance increased`, 'success');

        // Reload stores list to reflect changes
        await loadStores(true);

        hideLoading();
    } catch (error) {
        console.error('Error removing payment:', error);
        showToast(error.message || 'Failed to remove payment', 'error');
        hideLoading();
    }
}

// Append payment to history and update totals
async function appendPayment(paymentAmount) {
    if (!currentStoreDetail || !currentStoreDetail.store) return;

    try {
        showLoading();

        const phone = currentStoreDetail.store.phone;
        const timestamp = new Date().toISOString();

        console.group('%c💰 Payment Append - Request', 'color:#0ea5e9; font-weight:bold;');
        console.log('Path: /admin/api/stores/{phone}/payment-history');
        console.log('Payload:', { phone, paymentAmount, timestamp });
        console.log('Current totals:', {
            totalDue: currentStoreDetail.totalDue,
            totalPaid: currentStoreDetail.totalPaid,
            balance: currentStoreDetail.totalDue - currentStoreDetail.totalPaid
        });
        console.groupEnd();

        const response = await fetch(`/admin/api/stores/${phone}/payment-history`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ amount: paymentAmount, timestamp: timestamp })
        });

        if (!response.ok) {
            const data = await response.json();
            throw new Error(data.detail || 'Failed to add payment');
        }

        const data = await response.json();
        console.group('%c💾 Payment Append - Response', 'color:#22c55e; font-weight:bold;');
        console.log('Status: ok');
        console.log('Response body:', data);
        console.groupEnd();

        // Update local state - calculate new totals
        const newTotalPaid = (currentStoreDetail.totalPaid || 0) + paymentAmount;
        currentStoreDetail.totalPaid = newTotalPaid;
        currentStoreDetail.store.total_paid = newTotalPaid;
        currentStoreDetail.store.all_time_paid = newTotalPaid;

        // Append to payment history
        if (!currentStoreDetail.store.payment_history) {
            currentStoreDetail.store.payment_history = [];
        }
        currentStoreDetail.store.payment_history.push({
            amount: paymentAmount,
            timestamp: timestamp
        });

        // Update display
        const balance = currentStoreDetail.totalDue - newTotalPaid;
        currentStoreDetail.store.all_time_balance = balance;
        document.getElementById('detailBalance').textContent = `₹${formatCurrency(balance)}`;
        renderPaymentHistory();

        showToast(`Payment of ₹${formatCurrency(paymentAmount)} added successfully`, 'success');

        // Reload stores list to reflect changes
        await loadStores(true);

        hideLoading();
    } catch (error) {
        console.error('Error adding payment:', error);
        showToast(error.message || 'Failed to add payment', 'error');
        hideLoading();
    }
}

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

        params.append('limit', 20);  // Increased limit to ensure we find exact match
        params.append('skip', 0);

        const response = await fetch(`/admin/api/stores/list?${params.toString()}`, {
            headers: { 'Cache-Control': 'no-cache', 'Pragma': 'no-cache' }
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const data = await response.json();
        const stores = data.stores || [];

        // Find exact match (case-insensitive)
        const store = stores.find(s => (s.store_name || '').toLowerCase() === storeName.toLowerCase());

        if (store) {
            // Check if already exists in preview table
            const existingIndex = exportSelectedList.findIndex(s => (s.store_name || '').toLowerCase() === storeName.toLowerCase());

            if (existingIndex >= 0) {
                // Already added - show message
                showToast(`"${store.store_name}" is already in export list`, 'info');
            } else {
                // Add to top of preview table
                exportSelectedList.unshift(store);
                exportFilteredList = [...exportSelectedList];
                renderExportPreview();
                showToast(`✅ Added "${store.store_name}" to export list`, 'success');
            }

            // Refresh search results to update button state
            if (exportSearchTerm) {
                await searchExportStores(exportSearchTerm);
            }
        } else {
            showToast(`Store "${storeName}" not found`, 'warning');
        }
    } catch (err) {
        console.error('Failed to add store:', err);
        showToast('Failed to add store: ' + err.message, 'error');
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
        // Filter out stores with 0 orders
        exportSelectedList = exportStoreList.filter(store => (store.order_count || 0) > 0);
        exportFilteredList = [...exportSelectedList];
        // Sort by most orders by default
        sortExportByOrdersMost();

        // Load statistics with the same date filters to ensure they match the export data
        await loadStatistics();
    } catch (err) {
        console.error('Export load failed', err);
        document.getElementById('exportPreviewBody').innerHTML = '<tr><td colspan="3" style="text-align:center; padding:20px; color:#d32f2f;">Failed to load stores</td></tr>';
    } finally {
        hideLoading();
    }
}

function renderExportPreview() {
    const tbody = document.getElementById('exportPreviewBody');
    // Filter out stores with 0 orders
    const storesWithOrders = exportFilteredList.filter(store => (store.order_count || 0) > 0);

    if (!storesWithOrders.length) {
        tbody.innerHTML = '<tr><td colspan="3" style="text-align:center; padding:20px; color:#9ca3af;"><i class="fas fa-inbox"></i> No stores with orders found</td></tr>';
        return;
    }
    tbody.innerHTML = storesWithOrders.map(store => `
        <tr>
            <td><i class="fas fa-store" style="margin-right:8px; color:#1B5E20;"></i>${store.store_name || 'Unnamed Store'}</td>
            <td>${store.order_count || 0}</td>
            <td>₹${formatCurrency(store.total_revenue || 0)}</td>
        </tr>
    `).join('');
}

/**
 * Sort export preview by orders - Most (descending)
 */
function sortExportByOrdersMost() {
    if (!exportFilteredList || exportFilteredList.length === 0) return;

    exportFilteredList.sort((a, b) => {
        const ordersA = a.order_count || 0;
        const ordersB = b.order_count || 0;
        return ordersB - ordersA; // Descending: most first
    });

    renderExportPreview();
    showToast('📊 Sorted by most orders');
}

/**
 * Sort export preview by orders - Least (ascending)
 */
function sortExportByOrdersLeast() {
    if (!exportFilteredList || exportFilteredList.length === 0) return;

    exportFilteredList.sort((a, b) => {
        const ordersA = a.order_count || 0;
        const ordersB = b.order_count || 0;
        return ordersA - ordersB; // Ascending: least first
    });

    renderExportPreview();
    showToast('📊 Sorted by least orders');
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
    if (!exportFilteredList || !exportFilteredList.length) {
        showToast('Add at least one store to export', 'error');
        return;
    }
    await exportToPDF(exportFilteredList);
    closeExportModal();
}

// Open date range picker modal
function handleDateFilterChange() {
    const dateFilter = document.getElementById('dateFilter');
    const selectedValue = dateFilter.value;

    // Reset quick filter buttons when using manual date selection
    if (selectedValue !== 'all') {
        document.querySelectorAll('.quick-filter-btn').forEach(btn => {
            btn.classList.remove('active');
        });
        currentQuickFilter = null;
    }

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

    // Reset quick filter buttons to 'All Time'
    document.querySelectorAll('.quick-filter-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    const allTimeBtn = document.querySelector('[data-filter=\"all\"]');
    if (allTimeBtn) {
        allTimeBtn.classList.add('active');
    }
    currentQuickFilter = 'all';

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
        console.log('[EXPORT] Starting PDF export...');
        // Show loading
        showLoading();

        // First, ensure statistics are loaded with current filters
        try {
            console.log('[EXPORT] Loading statistics...');
            await loadStatistics();
            console.log('[EXPORT] Statistics loaded successfully');
        } catch (statsError) {
            console.error('[EXPORT] Statistics loading failed, continuing with export:', statsError);
        }

        // Accept pre-filtered list (from preview modal) or fetch if not provided
        let allStoresForExport = Array.isArray(arguments[0]) ? arguments[0] : null;
        console.log('[EXPORT] Pre-filtered list:', allStoresForExport ? `${allStoresForExport.length} stores` : 'null, will fetch');
        if (!allStoresForExport || !allStoresForExport.length) {
            console.log('[EXPORT] Fetching stores from API...');
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
            console.log('[EXPORT] Fetched', allStoresForExport.length, 'stores');
            exportStoreList = allStoresForExport;
            exportFilteredList = [...exportStoreList];
        }

        // Get jsPDF from global
        console.log('[EXPORT] Checking jsPDF availability...');
        if (!window.jspdf || !window.jspdf.jsPDF) {
            throw new Error('jsPDF library not loaded. Please refresh the page.');
        }
        const { jsPDF } = window.jspdf;
        console.log('[EXPORT] Creating PDF document...');
        const doc = new jsPDF();

        // Get current statistics (now reflects the applied filters)
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

        // Add store details header
        doc.setFontSize(12);
        doc.text('Store Details', 14, yPos);
        yPos += 7;

        // Render stores with Tamil support using images
        doc.setFontSize(10);
        doc.setTextColor(0);

        // Table header with better alignment
        doc.setFillColor(27, 94, 32); // Dark green
        doc.rect(14, yPos, 200, 10, 'F');
        doc.setTextColor(255, 255, 255);
        doc.setFontSize(11);
        doc.setFont(undefined, 'bold');
        doc.text('Store Name', 16, yPos + 6.5);
        doc.text('Orders', 130, yPos + 6.5, { align: 'right' });
        doc.text('Revenue', 190, yPos + 6.5, { align: 'right' });
        yPos += 12;

        // Add stores one by one (filter out stores with 0 orders)
        doc.setTextColor(0);
        doc.setFont(undefined, 'normal');
        doc.setFontSize(10);
        let rowColor = true;

        // Filter out stores with 0 orders before adding to PDF
        const storesForPDF = allStoresForExport.filter(store => (store.order_count || 0) > 0);

        for (let i = 0; i < storesForPDF.length; i++) {
            const store = storesForPDF[i];
            const storeName = store.store_name || 'Unnamed Store';
            const hasTamil = /[\u0B80-\u0BFF]/.test(storeName);

            // Check if we need a new page
            if (yPos > 270) {
                doc.addPage();
                yPos = 20;

                // Re-add header on new page
                doc.setFillColor(27, 94, 32);
                doc.rect(14, yPos, 200, 10, 'F');
                doc.setTextColor(255, 255, 255);
                doc.setFontSize(11);
                doc.setFont(undefined, 'bold');
                doc.text('Store Name', 16, yPos + 6.5);
                doc.text('Orders', 130, yPos + 6.5, { align: 'right' });
                doc.text('Revenue', 190, yPos + 6.5, { align: 'right' });
                yPos += 12;
                doc.setTextColor(0);
                doc.setFont(undefined, 'normal');
                doc.setFontSize(10);
                rowColor = true;
            }

            // Alternate row background
            if (rowColor) {
                doc.setFillColor(240, 253, 244); // Light green
                doc.rect(14, yPos, 200, 10, 'F');
            }
            rowColor = !rowColor;

            // Add store name (as image if Tamil, as text if English)
            if (hasTamil) {
                const imgData = await renderTextAsImage(storeName, 10);
                doc.addImage(imgData, 'PNG', 16, yPos + 2, 100, 6);
            } else {
                doc.text(storeName, 16, yPos + 6.5);
            }

            // Add orders and revenue (right-aligned)
            const orders = (store.order_count || 0).toString();
            const revenue = `Rs.${formatCurrency(store.total_revenue || 0)}`;
            doc.text(orders, 130, yPos + 6.5, { align: 'right' });
            doc.text(revenue, 190, yPos + 6.5, { align: 'right' });

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
        console.error('[EXPORT] Error exporting PDF:', error);
        console.error('[EXPORT] Error details:', {
            message: error.message,
            stack: error.stack,
            name: error.name
        });
        hideLoading();
        showToast(`Failed to export PDF: ${error.message}`, 'error');
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

// ============ MONTHLY SUMMARY FEATURE ============

/**
 * Show Monthly Summary modal with daily breakdown
 */
async function showMonthlySummary() {
    const modal = document.getElementById('monthlySummaryModal');
    const loadingDiv = document.getElementById('summaryLoading');
    const contentDiv = document.getElementById('summaryContent');
    const monthYearSpan = document.getElementById('summaryMonthYear');

    // Show modal with loading state
    modal.style.display = 'flex';
    loadingDiv.style.display = 'block';
    contentDiv.style.display = 'none';

    // Get current month and year
    const now = new Date();
    const currentMonth = now.getMonth();
    const currentYear = now.getFullYear();
    const currentDay = now.getDate();

    // Format month name
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
    monthYearSpan.textContent = `${monthNames[currentMonth]} ${currentYear}`;

    // Show progress message
    const TARGET_BATCHES = 10;
    const BATCH_SIZE = Math.max(1, Math.ceil(currentDay / TARGET_BATCHES)); // aim for ~10 parallel batches
    const totalBatches = Math.ceil(currentDay / BATCH_SIZE);
    loadingDiv.innerHTML = `
        <i class="fas fa-spinner fa-spin" style="font-size: 48px; margin-bottom: 15px; color: #1B5E20;"></i>
        <p style="font-weight: 600; font-size: 16px;">Loading daily breakdown...</p>
        <p style="font-size: 14px; color: #666; margin-top: 8px;">Fetching data for ${currentDay} days (${totalBatches} parallel batches)</p>
    `;

    try {
        // Fetch daily breakdown for current month
        const startTime = Date.now();
        const dailyData = await fetchDailyBreakdown(currentYear, currentMonth, currentDay);
        const loadTime = ((Date.now() - startTime) / 1000).toFixed(2);

        console.log(`⚡ Monthly summary loaded in ${loadTime}s`);

        // Display the summary
        displayMonthlySummary(dailyData, currentDay);

        // Hide loading, show content
        loadingDiv.style.display = 'none';
        contentDiv.style.display = 'block';

    } catch (error) {
        console.error('Error loading monthly summary:', error);
        loadingDiv.innerHTML = `
            <div style="color: #d32f2f;">
                <i class="fas fa-exclamation-triangle" style="font-size: 48px; margin-bottom: 15px;"></i>
                <p>Failed to load monthly summary</p>
                <p style="font-size: 14px; margin-top: 10px;">${error.message}</p>
            </div>
        `;
    }
}

/**
 * Fetch daily breakdown data for the current month using optimized batched parallel requests
 */
async function fetchDailyBreakdown(year, month, currentDay) {
    console.log('📊 Fetching daily breakdown for', year, month, currentDay);

    // Initialize daily stats array
    const dailyStats = [];
    for (let day = 1; day <= currentDay; day++) {
        dailyStats.push({
            day: day,
            date: new Date(year, month, day),
            orders: 0,
            revenue: 0
        });
    }

    try {
        // Fetch statistics in batches sized to target ~10 parallel batches for faster completion
        const TARGET_BATCHES = 10;
        const BATCH_SIZE = Math.max(1, Math.ceil(currentDay / TARGET_BATCHES));
        const batches = [];

        for (let startDay = 1; startDay <= currentDay; startDay += BATCH_SIZE) {
            const endDay = Math.min(startDay + BATCH_SIZE - 1, currentDay);
            batches.push({ startDay, endDay });
        }

        console.log(`📦 Fetching ${batches.length} batches (${BATCH_SIZE} days each) in parallel`);

        // Execute all batches in parallel for maximum speed
        const batchPromises = batches.map(async ({ startDay, endDay }) => {
            const batchResults = [];

            // Fetch each day in the batch sequentially (to avoid overwhelming the server)
            for (let day = startDay; day <= endDay; day++) {
                const date = new Date(year, month, day);
                const dateStr = formatDateForAPI(date);

                try {
                    const response = await fetch(
                        `/admin/api/stores/statistics?start_date=${dateStr}&end_date=${dateStr}&t=${Date.now()}`,
                        { signal: AbortSignal.timeout(5000) } // 5 second timeout per request
                    );

                    if (response.ok) {
                        const data = await response.json();
                        // API returns: { success: true, statistics: { total_orders, total_revenue, ... } }
                        const stats = data.statistics || {};
                        console.log(`📅 Day ${day} (${dateStr}): ${stats.total_orders || 0} orders, ₹${stats.total_revenue || 0}`);
                        batchResults.push({
                            day: day,
                            orders: stats.total_orders || 0,
                            revenue: stats.total_revenue || 0
                        });
                    } else {
                        console.error(`❌ Failed to fetch day ${day}: HTTP ${response.status}`);
                        batchResults.push({ day: day, orders: 0, revenue: 0 });
                    }
                } catch (error) {
                    console.error(`❌ Failed to fetch day ${day} (${formatDateForAPI(new Date(year, month, day))}):`, error.message);
                    batchResults.push({ day: day, orders: 0, revenue: 0 });
                }
            }

            return batchResults;
        });

        // Wait for all batches to complete
        const allBatchResults = await Promise.all(batchPromises);

        // Flatten and merge results
        const dayResults = allBatchResults.flat();

        // Update daily stats with fetched data
        dayResults.forEach(result => {
            const dayIndex = result.day - 1;
            if (dayIndex >= 0 && dayIndex < dailyStats.length) {
                dailyStats[dayIndex].orders = result.orders;
                dailyStats[dayIndex].revenue = result.revenue;
            }
        });

        console.log('✅ Daily stats fetched successfully:', dailyStats.length, 'days');
        return dailyStats;

    } catch (error) {
        console.error('❌ Error fetching daily breakdown:', error);
        return dailyStats; // Return empty stats on error
    }
}

/**
 * Format date for API (YYYY-MM-DD)
 */
function formatDateForAPI(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

/**
 * Format date for display (DD MMM)
 */
function formatDateForDisplay(date) {
    const day = date.getDate();
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return `${day} ${monthNames[date.getMonth()]}`;
}

/**
 * Display monthly summary in the modal
 */
function displayMonthlySummary(dailyData, currentDay) {
    // Calculate totals
    const totalOrders = dailyData.reduce((sum, day) => sum + day.orders, 0);
    const totalRevenue = dailyData.reduce((sum, day) => sum + day.revenue, 0);
    const avgRevenue = currentDay > 0 ? totalRevenue / currentDay : 0;

    // Update summary stats cards
    document.getElementById('summaryTotalDays').textContent = currentDay;
    document.getElementById('summaryTotalOrders').textContent = totalOrders.toLocaleString();
    document.getElementById('summaryTotalRevenue').textContent = `₹${totalRevenue.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    document.getElementById('summaryAvgRevenue').textContent = `₹${avgRevenue.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

    // Populate table (reverse order - most recent first)
    const tbody = document.getElementById('summaryTableBody');
    tbody.innerHTML = dailyData.reverse().map(dayData => `
        <tr>
            <td>Day ${dayData.day}</td>
            <td>${formatDateForDisplay(dayData.date)}</td>
            <td>${dayData.orders.toLocaleString()}</td>
            <td>₹${dayData.revenue.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
        </tr>
    `).join('');
}

/**
 * Close Monthly Summary modal
 */
function closeMonthlySummary() {
    const modal = document.getElementById('monthlySummaryModal');
    modal.style.display = 'none';
}

// Close modal when clicking outside
window.addEventListener('click', function (event) {
    const modal = document.getElementById('monthlySummaryModal');
    if (event.target === modal) {
        closeMonthlySummary();
    }
});

// ============ END MONTHLY SUMMARY FEATURE ============

// ============ EXPORT SUMMARY FEATURE ============

// Export summary state
let exportSummaryFilters = {
    start_date: '',
    end_date: ''
};

/**
 * Show Export Summary Type menu
 */
function showExportSummaryMenu() {
    const modal = document.getElementById('exportSummaryTypeModal');
    modal.style.display = 'flex';
}

function closeExportSummaryTypeModal() {
    document.getElementById('exportSummaryTypeModal').style.display = 'none';
}

/**
 * Show Export Daily Date Picker
 */
function showExportDailyDatePicker() {
    closeExportSummaryTypeModal();
    const modal = document.getElementById('exportDailyDateModal');
    const grid = document.getElementById('exportDailyDatesGrid');

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const currentDay = today.getDate();
    const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();

    grid.innerHTML = '';

    const lastDayToShow = Math.min(currentDay, daysInMonth);

    for (let day = 1; day <= lastDayToShow; day++) {
        const date = new Date(now.getFullYear(), now.getMonth(), day);
        const btn = document.createElement('button');
        btn.className = 'date-selector-btn';
        btn.textContent = day;

        if (day === currentDay) {
            btn.style.backgroundColor = '#2196F3';
            btn.style.color = 'white';
            btn.style.fontWeight = '700';
        }

        btn.onclick = () => {
            const dateStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
            applyExportDailyFilter(dateStr);
            closeExportDailyDateModal();
        };
        grid.appendChild(btn);
    }

    modal.style.display = 'flex';
}

function closeExportDailyDateModal() {
    document.getElementById('exportDailyDateModal').style.display = 'none';
}

function applyExportDailyFilter(dateStr) {
    exportSummaryFilters.start_date = dateStr;
    exportSummaryFilters.end_date = dateStr;

    const dateObj = new Date(dateStr);
    const dateDisplay = dateObj.toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: 'numeric' });

    // Update the main export date filter dropdown to reflect the change
    document.getElementById('exportDateFilter').value = 'single';
    document.getElementById('exportDateDisplayGroup').style.display = 'block';
    document.getElementById('exportDateDisplay').textContent = dateDisplay;

    // Load export data with this date filter
    loadExportData(dateStr, dateStr);
}

/**
 * Show Export Weekly Selector
 */
function showExportWeeklySelector() {
    closeExportSummaryTypeModal();
    const modal = document.getElementById('exportWeeklyModal');
    const container = document.getElementById('exportWeeklyWeeksContainer');

    const now = new Date();
    const currentDay = now.getDate();
    const currentWeekNum = Math.ceil(currentDay / 7);

    container.innerHTML = '';

    const weeks = [];
    for (let startDay = 1; startDay <= currentDay; startDay += 7) {
        const endDay = Math.min(startDay + 6, currentDay);
        weeks.push({ num: Math.ceil(startDay / 7), startDay, endDay });
    }

    weeks.forEach(week => {
        const btn = document.createElement('button');
        btn.className = 'week-selector-btn';
        btn.style.padding = '12px';
        btn.style.border = '1px solid #ddd';
        btn.style.borderRadius = '8px';
        btn.style.background = '#f9f9f9';
        btn.style.cursor = 'pointer';
        btn.style.transition = 'all 0.3s';
        btn.style.minHeight = '60px';
        btn.innerHTML = `<div style="font-weight: 600; margin-bottom: 4px;">Week ${week.num}</div><div style="font-size: 13px; color: #666;">${week.startDay} - ${week.endDay}</div>`;

        if (week.num === currentWeekNum) {
            btn.style.backgroundColor = '#2196F3';
            btn.style.color = 'white';
            btn.style.fontWeight = '700';
            btn.style.borderColor = '#2196F3';
        }

        btn.onclick = () => {
            const date = new Date(now.getFullYear(), now.getMonth(), week.startDay);
            const startStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(week.startDay).padStart(2, '0')}`;
            const endStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(week.endDay).padStart(2, '0')}`;
            applyExportWeeklyFilter(startStr, endStr);
            closeExportWeeklyModal();
        };

        container.appendChild(btn);
    });

    modal.style.display = 'flex';
}

function closeExportWeeklyModal() {
    document.getElementById('exportWeeklyModal').style.display = 'none';
}

function applyExportWeeklyFilter(startStr, endStr) {
    exportSummaryFilters.start_date = startStr;
    exportSummaryFilters.end_date = endStr;

    const startDate = new Date(startStr);
    const endDate = new Date(endStr);
    const startDay = startDate.getDate();
    const endDay = endDate.getDate();
    const monthName = startDate.toLocaleDateString('en-IN', { month: 'short' });
    const weekDisplay = `Week: ${startDay} - ${endDay} ${monthName}`;

    // Update the main export date filter dropdown to reflect the change
    document.getElementById('exportDateFilter').value = 'range';
    document.getElementById('exportDateDisplayGroup').style.display = 'block';
    document.getElementById('exportDateDisplay').textContent = weekDisplay;

    // Load export data with this date filter
    loadExportData(startStr, endStr);
}

/**
 * Show Export Monthly Selector
 */
function showExportMonthlySelector() {
    closeExportSummaryTypeModal();
    const modal = document.getElementById('exportMonthlyModal');
    const grid = document.getElementById('exportMonthlyMonthsGrid');

    const now = new Date();
    const currentMonthIndex = now.getMonth();
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    grid.innerHTML = '';

    for (let monthIndex = 0; monthIndex < 12; monthIndex++) {
        const btn = document.createElement('button');
        btn.className = 'month-selector-btn';
        btn.style.padding = '10px';
        btn.style.border = '1px solid #ddd';
        btn.style.borderRadius = '8px';
        btn.style.background = '#f9f9f9';
        btn.style.cursor = 'pointer';
        btn.textContent = monthNames[monthIndex];

        if (monthIndex === currentMonthIndex) {
            btn.style.backgroundColor = '#2196F3';
            btn.style.color = 'white';
            btn.style.fontWeight = '700';
            btn.style.borderColor = '#2196F3';
        }

        btn.onclick = () => {
            const startStr = `${now.getFullYear()}-${String(monthIndex + 1).padStart(2, '0')}-01`;
            const lastDay = new Date(now.getFullYear(), monthIndex + 1, 0).getDate();
            const endStr = `${now.getFullYear()}-${String(monthIndex + 1).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
            applyExportMonthlyFilter(startStr, endStr, monthNames[monthIndex]);
            closeExportMonthlyModal();
        };

        grid.appendChild(btn);
    }

    modal.style.display = 'flex';
}

function closeExportMonthlyModal() {
    document.getElementById('exportMonthlyModal').style.display = 'none';
}

function applyExportMonthlyFilter(startStr, endStr, monthName) {
    exportSummaryFilters.start_date = startStr;
    exportSummaryFilters.end_date = endStr;

    // Update the main export date filter dropdown to reflect the change
    document.getElementById('exportDateFilter').value = 'range';
    document.getElementById('exportDateDisplayGroup').style.display = 'block';
    document.getElementById('exportDateDisplay').textContent = monthName;

    // Load export data with this date filter
    loadExportData(startStr, endStr);
}

/**
 * Show Export Yearly Selector
 */
function showExportYearlySelector() {
    closeExportSummaryTypeModal();
    const modal = document.getElementById('exportYearlyModal');
    const grid = document.getElementById('exportYearlyYearsGrid');

    const now = new Date();
    const currentYear = now.getFullYear();

    grid.innerHTML = '';

    for (let year = 2020; year <= currentYear; year++) {
        const btn = document.createElement('button');
        btn.className = 'year-selector-btn';
        btn.style.padding = '10px';
        btn.style.border = '1px solid #ddd';
        btn.style.borderRadius = '8px';
        btn.style.background = '#f9f9f9';
        btn.style.cursor = 'pointer';
        btn.textContent = year;

        if (year === currentYear) {
            btn.style.backgroundColor = '#2196F3';
            btn.style.color = 'white';
            btn.style.fontWeight = '700';
            btn.style.borderColor = '#2196F3';
        }

        btn.onclick = () => {
            const startStr = `${year}-01-01`;
            const endStr = `${year}-12-31`;
            applyExportYearlyFilter(startStr, endStr, year);
            closeExportYearlyModal();
        };

        grid.appendChild(btn);
    }

    modal.style.display = 'flex';
}

function closeExportYearlyModal() {
    document.getElementById('exportYearlyModal').style.display = 'none';
}

function applyExportYearlyFilter(startStr, endStr, year) {
    exportSummaryFilters.start_date = startStr;
    exportSummaryFilters.end_date = endStr;

    const yearDisplay = `Year ${year}`;

    // Update the main export date filter dropdown to reflect the change
    document.getElementById('exportDateFilter').value = 'range';
    document.getElementById('exportDateDisplayGroup').style.display = 'block';
    document.getElementById('exportDateDisplay').textContent = yearDisplay;

    // Load export data with this date filter
    loadExportData(startStr, endStr);
}

/**
 * Clear Export Summary Filter (All Time)
 */
function clearExportSummaryFilter() {
    closeExportSummaryTypeModal();
    exportSummaryFilters.start_date = '';
    exportSummaryFilters.end_date = '';

    // Reset the main export date filter
    document.getElementById('exportDateFilter').value = 'all';
    document.getElementById('exportDateDisplayGroup').style.display = 'none';
    document.getElementById('exportDateDisplay').textContent = '';

    // Load all export data without date filter
    loadExportData();
}

/**
 * Load export preview with date filter applied
 */
function loadExportPreviewWithDateFilter() {
    const startDate = exportSummaryFilters.start_date;
    const endDate = exportSummaryFilters.end_date;

    if (startDate && endDate) {
        loadExportData(startDate, endDate);
    } else {
        loadExportData();
    }
}

// ============ END EXPORT SUMMARY FEATURE ============

// ============ MANUAL STORE ADDITION FOR EXPORT ============
let manuallyAddedStores = [];

function toggleAddStoreUI() {
    const ui = document.getElementById('addStoreUI');
    const list = document.getElementById('addedStoresList');

    if (ui.style.display === 'none') {
        ui.style.display = 'block';
        list.style.display = manuallyAddedStores.length > 0 ? 'block' : 'none';

        // Set default date to today
        const today = new Date().toISOString().split('T')[0];
        document.getElementById('addStoreDate').value = today;
    } else {
        ui.style.display = 'none';
        list.style.display = 'none';
    }
}

// Debounce for store search
let addStoreSearchTimeout;
function handleAddStoreSearch() {
    clearTimeout(addStoreSearchTimeout);
    const query = document.getElementById('addStoreSearch').value;

    if (query.length < 2) {
        document.getElementById('addStoreSearchResults').style.display = 'none';
        return;
    }

    addStoreSearchTimeout = setTimeout(async () => {
        try {
            const response = await fetch(`/admin/api/stores/list?search=${encodeURIComponent(query)}&limit=5`);
            const data = await response.json();

            const resultsDiv = document.getElementById('addStoreSearchResults');
            if (data.stores && data.stores.length > 0) {
                resultsDiv.innerHTML = data.stores.map(store => `
                    <div onclick="selectStoreForAdd('${store.store_name}', '${store.phone}')" 
                         style="padding: 10px; cursor: pointer; border-bottom: 1px solid #eee; hover: background: #f9f9f9;">
                        <div style="font-weight: 600;">${store.store_name}</div>
                        <div style="font-size: 12px; color: #666;">${store.phone}</div>
                    </div>
                `).join('');
                resultsDiv.style.display = 'block';
            } else {
                resultsDiv.innerHTML = '<div style="padding: 10px; color: #666;">No stores found</div>';
                resultsDiv.style.display = 'block';
            }
        } catch (error) {
            console.error('Search failed', error);
        }
    }, 300);
}

function selectStoreForAdd(name, phone) {
    document.getElementById('addStoreSearch').value = name;
    document.getElementById('addStoreSearch').dataset.selectedPhone = phone;
    document.getElementById('addStoreSearchResults').style.display = 'none';
}

async function applyAddStore() {
    const date = document.getElementById('addStoreDate').value;
    const storeName = document.getElementById('addStoreSearch').value;
    const phone = document.getElementById('addStoreSearch').dataset.selectedPhone;

    if (!date || !storeName) {
        showToast('Please select a date and store', 'error');
        return;
    }

    try {
        showLoading();
        // Fetch stats for this specific store and date
        const params = new URLSearchParams({
            search: storeName, // Use search to find the specific store
            start_date: date,
            end_date: date,
            limit: 10
        });

        const response = await fetch(`/admin/api/stores/list?${params.toString()}`);
        const data = await response.json();

        const store = data.stores ? data.stores.find(s => s.store_name === storeName) : null;

        if (store) {
            // Check if already in manual list
            const existingId = `${store.store_name}-${date}`;
            if (manuallyAddedStores.some(s => `${s.store_name}-${s.targetDate}` === existingId)) {
                showToast('Store already added for this date', 'warning');
            } else {
                // Add to manual list with the specific date context
                store.targetDate = date;
                store.isManual = true;
                manuallyAddedStores.push(store);

                renderAddedStoresList();
                refreshExportPreview();
                showToast('Store added to export', 'success');

                // Clear inputs
                document.getElementById('addStoreSearch').value = '';
                delete document.getElementById('addStoreSearch').dataset.selectedPhone;
            }
        } else {
            showToast('Could not fetch store details for this date', 'error');
        }
    } catch (error) {
        console.error('Add store error', error);
        showToast('Failed to add store', 'error');
    } finally {
        hideLoading();
    }
}

function renderAddedStoresList() {
    const container = document.getElementById('addedStoresContainer');
    const listDiv = document.getElementById('addedStoresList');

    if (manuallyAddedStores.length === 0) {
        listDiv.style.display = 'none';
        return;
    }

    listDiv.style.display = 'block';
    container.innerHTML = manuallyAddedStores.map((store, index) => `
        <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 12px; background: white; border: 1px solid #e5e7eb; border-radius: 6px;">
            <div>
                <div style="font-weight: 600; font-size: 14px;">${store.store_name}</div>
                <div style="font-size: 12px; color: #666;">
                    ${formatDateForDisplay(new Date(store.targetDate))} • 
                    ${store.order_count} Orders • 
                    ₹${formatCurrency(store.total_revenue)}
                </div>
            </div>
            <button onclick="removeAddedStore(${index})" style="background: none; border: none; color: #ef4444; cursor: pointer; padding: 4px;">
                <i class="fas fa-times"></i>
            </button>
        </div>
    `).join('');
}

function removeAddedStore(index) {
    manuallyAddedStores.splice(index, 1);
    renderAddedStoresList();
    refreshExportPreview();
}

// Override renderExportPreview to include manual stores and Total Revenue
const originalRenderExportPreview = renderExportPreview; // Backup if needed, but we'll reimplement

// We need to merge lists just before rendering
function refreshExportPreview() {
    const tbody = document.getElementById('exportPreviewBody');
    const totalRevUi = document.getElementById('exportTotalRevenue');
    const totalRevVal = document.getElementById('exportTotalRevenueValue');

    // Combine filtered list and manual stores
    // Note: exportFilteredList is the main list from "Summary" filters
    let combinedList = [...exportFilteredList];

    // Add manual stores (avoid duplicates if they are already in the list for the same reason?? 
    // Actually, manual stores might be for different dates than the main filter. 
    // We will just append them. User can manage overlap manually.)
    manuallyAddedStores.forEach(manualStore => {
        // Optional: Check duplication based on ID if needed, but user might want to compare same store across dates
        combinedList.push(manualStore);
    });

    // Sort combined list if needed (preserve sort order selected by user?)
    // For now, just append manual ones at top or bottom? User requested "below addstore...". 
    // The list is in the table. Let's keep manual stores at the TOP for visibility.
    // Actually, let's keep them separate in data but render together.

    // Actually, let's just use the combined list for rendering.
    // If sort is active, we might want to sort properly.
    // But manual stores usually imply "specific checks". We'll just append them to the main list for display.

    const finalDisplayList = [...manuallyAddedStores, ...exportFilteredList];

    // Calculate Total Revenue
    const totalRevenue = finalDisplayList.reduce((sum, store) => sum + (store.total_revenue || 0), 0);

    // Update Revenue UI
    if (finalDisplayList.length > 0) {
        totalRevUi.style.display = 'block';
        totalRevVal.textContent = `₹${formatCurrency(totalRevenue)}`;
    } else {
        totalRevUi.style.display = 'none';
        tbody.innerHTML = '<tr><td colspan="3" style="text-align:center; padding:20px; color:#9ca3af;"><i class="fas fa-inbox"></i> No stores found</td></tr>';
        return;
    }

    tbody.innerHTML = finalDisplayList.map(store => {
        const isManual = store.isManual;
        return `
        <tr style="${isManual ? 'background-color: #f0fdf4;' : ''}">
            <td>
                <i class="fas fa-store" style="margin-right:8px; color:${isManual ? '#166534' : '#1B5E20'};"></i>
                ${store.store_name || 'Unnamed Store'}
                ${isManual ? `<span style="font-size:10px; background:#dcfce7; color:#166534; padding:2px 4px; border-radius:4px; margin-left:4px;">${formatDateForDisplay(new Date(store.targetDate))}</span>` : ''}
            </td>
            <td>${store.order_count || 0}</td>
            <td>₹${formatCurrency(store.total_revenue || 0)}</td>
        </tr>
    `}).join('');
}

// Override handleExportSearch to use the refresh logic
// BUT handleExportSearch updates `exportFilteredList`. 
// So searching the main list should still work.
// We just need to make sure `renderExportPreview` (which we effectively replaced with `refreshExportPreview`) is called.

// Override the global renderExportPreview function
renderExportPreview = refreshExportPreview;


// Override exportToPDF to include Total Revenue and Manual Stores
async function exportToPDF(stores) {
    // Combine with manual stores logic again
    // The caller `downloadExportPDF` passes `exportFilteredList` or nothing.
    // We rely on `refreshExportPreview`'s logic to get the full list.
    const finalExportList = [...manuallyAddedStores, ...exportFilteredList];

    if (finalExportList.length === 0) {
        showToast('Add at least one store to export', 'error');
        return;
    }

    showLoading();
    try {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF();

        // Add Logo/Header
        doc.setFillColor(27, 94, 32); // Dark Green
        doc.rect(0, 0, 210, 20, 'F');
        doc.setTextColor(255, 255, 255);
        doc.setFontSize(16);
        doc.setFont(undefined, 'bold');
        doc.text('AL-MATHINA DASH', 105, 13, { align: 'center' });

        // Add date
        doc.setFontSize(10);
        doc.setTextColor(100);
        const today = new Date().toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
        doc.text(`Generated: ${today}`, 14, 32);

        // Add Total Revenue Summary
        const totalRevenue = finalExportList.reduce((sum, store) => sum + (store.total_revenue || 0), 0);
        doc.setFillColor(224, 242, 241); // Light Teal
        doc.rect(14, 38, 180, 15, 'F');
        doc.setTextColor(0, 77, 64);
        doc.setFontSize(10);
        doc.text('ESTIMATED TOTAL REVENUE', 105, 43, { align: 'center' });
        doc.setFontSize(14);
        doc.setFont(undefined, 'bold');
        doc.text(`Rs.${formatCurrency(totalRevenue)}`, 105, 50, { align: 'center' });

        // Add Filter Info
        let yPos = 65;
        // ... (rest of filtering text logic from original) ...

        // Table Header
        doc.setFillColor(27, 94, 32);
        doc.rect(14, yPos, 180, 10, 'F');
        doc.setTextColor(255, 255, 255);
        doc.setFontSize(11);
        doc.text('Store Name', 16, yPos + 6.5);
        doc.text('Orders', 130, yPos + 6.5, { align: 'right' });
        doc.text('Revenue', 190, yPos + 6.5, { align: 'right' });
        yPos += 12;

        doc.setTextColor(0);
        doc.setFont(undefined, 'normal');
        doc.setFontSize(10);
        let rowColor = true;

        for (let i = 0; i < finalExportList.length; i++) {
            const store = finalExportList[i];
            const storeName = store.store_name || 'Unnamed Store';
            // Show date for manual entries
            const displayName = store.isManual
                ? `${storeName} (${formatDateForDisplay(new Date(store.targetDate))})`
                : storeName;

            const hasTamil = /[\u0B80-\u0BFF]/.test(displayName);

            if (yPos > 270) {
                doc.addPage();
                yPos = 20;
                // Header again
                doc.setFillColor(27, 94, 32);
                doc.rect(14, yPos, 180, 10, 'F');
                doc.setTextColor(255, 255, 255);
                doc.text('Store Name', 16, yPos + 6.5);
                doc.text('Orders', 130, yPos + 6.5, { align: 'right' });
                doc.text('Revenue', 190, yPos + 6.5, { align: 'right' });
                yPos += 12;
                doc.setTextColor(0);
            }

            if (rowColor) {
                doc.setFillColor(240, 253, 244);
                doc.rect(14, yPos, 180, 10, 'F');
            }
            rowColor = !rowColor;

            if (hasTamil) {
                const imgData = await renderTextAsImage(storeName, 10); // Rendering basic name
                doc.addImage(imgData, 'PNG', 16, yPos + 2, 100, 6);
                if (store.isManual) {
                    doc.setFontSize(8);
                    doc.text(`(${formatDateForDisplay(new Date(store.targetDate))})`, 16, yPos + 9);
                    doc.setFontSize(10);
                }
            } else {
                doc.text(displayName, 16, yPos + 6.5);
            }

            const orders = (store.order_count || 0).toString();
            const revenue = `Rs.${formatCurrency(store.total_revenue || 0)}`;
            doc.text(orders, 130, yPos + 6.5, { align: 'right' });
            doc.text(revenue, 190, yPos + 6.5, { align: 'right' });

            yPos += 10;
        }

        const filename = `revenue-report-${new Date().toISOString().split('T')[0]}.pdf`;
        doc.save(filename);
        showToast('PDF exported successfully!', 'success');

    } catch (error) {
        console.error('Export error', error);
        showToast('Export failed', 'error');
    } finally {
        hideLoading();
    }
}

// Update the downloader to just call our new exportToPDF with empty args (it handles the lists)
downloadExportPDF = async function () {
    await exportToPDF();
}
