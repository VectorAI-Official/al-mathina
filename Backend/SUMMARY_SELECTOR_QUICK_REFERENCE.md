# Summary Selector - Quick Reference

## Button Location
**Header** → Right side, next to other action buttons
- **Label**: Summary (with chart icon)
- **Class**: `btn btn-primary summary-btn`
- **Click Handler**: `onclick="showSummaryMenu()"`

## Modal Interaction Flow

```
┌─────────────────────────────────────────────────────┐
│  Click Summary Button → showSummaryMenu()            │
└──────────────┬──────────────────────────────────────┘
               │
               ▼
      ┌────────────────────┐
      │ summaryTypeModal   │
      ├────────────────────┤
      │ • All Time         │ → applyAllTimeFilter()
      │ • Daily           │ → showDailyDatePicker()
      │ • Weekly          │ → showWeeklySelector()
      │ • Monthly         │ → showMonthlySelector()
      │ • Yearly          │ → showYearlySelector()
      └────────────────────┘
               │
      ┌────────┴────────┬──────────┬──────────┐
      ▼                 ▼          ▼          ▼
   Daily            Weekly    Monthly    Yearly
  (31 dates)     (4-5 weeks) (12 months) (years)
      │                 │          │          │
      └─────────────────┴──────────┴──────────┘
               │
               ▼
    Apply filter + Reload data
```

## Functions Quick Reference

### Show Modals
```javascript
showSummaryMenu()           // Main menu
showDailyDatePicker()       // Date picker
showWeeklySelector()        // Week list
showMonthlySelector()       // Month list
showYearlySelector()        // Year list
```

### Close Modals
```javascript
closeSummaryTypeModal()
closeDailyDateModal()
closeWeeklyModal()
closeMonthlyModal()
closeYearlyModal()
```

### Apply Filters
```javascript
applyAllTimeFilter()
applyDailyFilter('2025-01-15')
applyWeeklyFilter('2025-01-01', '2025-01-07', 1)
applyMonthlyFilter('2025-01-01', '2025-01-31', 'January')
applyYearlyFilter(2025)
```

## CSS Classes

### Button Styling
- `.summary-btn` - Main button
- `.summary-option-btn` - Selection menu items
- `.date-selector-btn` - Date buttons (Daily)
- `.week-selector-btn` - Week buttons (Weekly)
- `.month-selector-btn` - Month buttons (Monthly)
- `.year-selector-btn` - Year buttons (Yearly)

### Modal Styling
- `.modal` - Modal container
- `.modal-content` - Modal box
- `.modal-header` - Header section
- `.modal-body` - Content section
- `.modal-close` - Close button

## Mobile Breakpoints

| Device | Width | Grid Columns | Button Size |
|--------|-------|--------------|-------------|
| Mobile | ≤480px | 50px | 40px height |
| Tablet | ≤768px | 60px | 44px height |
| Desktop | >768px | 70px | 50px height |

## API Integration

All filters work with the existing stores API:
```
GET /admin/api/stores/list?start_date=2025-01-01&end_date=2025-01-31
```

Filters are passed via `currentFilters` object:
```javascript
currentFilters = {
    search: '',
    start_date: '2025-01-01',
    end_date: '2025-01-31'
};
```

## Styling Customization

### Change Button Colors
Edit `.summary-btn` in `stores.css`:
```css
background: linear-gradient(135deg, #2196F3 0%, #1976D2 100%);
```

### Change Modal Width
Edit `.modal-content` in `stores.css`:
```css
max-width: 500px;  /* Change this */
width: 90%;
```

### Change Grid Columns
Edit grid properties for each selector:
```css
#dailyDatesGrid {
    grid-template-columns: repeat(auto-fill, minmax(70px, 1fr));
}
```

## Keyboard Support

Currently uses mouse/touch. To add keyboard support:

```javascript
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeSummaryTypeModal();
        closeDailyDateModal();
        closeWeeklyModal();
        closeMonthlyModal();
        closeYearlyModal();
    }
});
```

## Troubleshooting

### Modal doesn't open
- Check: `onclick="showSummaryMenu()"` on button
- Verify: Modal element ID matches function reference

### Dates not filtering correctly
- Check: Date format is `YYYY-MM-DD`
- Verify: `currentFilters` object is updated
- Check: `loadStores(true)` is called

### Mobile layout broken
- Check: Viewport meta tag in HTML
- Verify: CSS media queries are loaded
- Clear: Browser cache

### Week selector shows wrong dates
- Verify: Month/year calculation in `showWeeklySelector()`
- Check: Week start is Sunday (adjust if needed)

## Browser DevTools Console

Test functions directly:
```javascript
showSummaryMenu()          // Open menu
applyDailyFilter('2025-01-15')  // Apply daily filter
showToast('Test message')   // Show notification
```

## Performance Tips

- Modals are hidden by default (CSS `display: none`)
- Grids use CSS Grid (native, performant)
- Animations use CSS transforms (GPU accelerated)
- No expensive DOM operations
- Reuses existing date filter logic

## Maintenance

Files to edit for changes:
1. **Logic Changes**: `Backend/static/admin/js/stores.js`
2. **Layout Changes**: `Backend/static/admin/stores.html`
3. **Style Changes**: `Backend/static/admin/css/stores.css`

All functions are modular and independently testable.
