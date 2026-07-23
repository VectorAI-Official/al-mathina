package utils

import (
	"math"
	"strconv"
	"strings"
)

// ParseWeight parses a weight string like "500g", "1.5kg", "500ml", "1L"
// and returns the numeric value and sub-unit.
// Examples:
//
//	"500g"   → (500, "g")
//	"1.5kg"  → (1.5, "kg")
//	"500ml"  → (500, "ml")
//	"1L"     → (1, "L")
//	"25kg"   → (25, "kg")
//	""       → (0, "")
func ParseWeight(weight string) (float64, string) {
	weight = strings.TrimSpace(weight)
	if weight == "" {
		return 0, ""
	}

	weight = strings.ToLower(weight)

	// Known sub-units ordered by length (longest first) to match correctly
	subUnits := []string{"kg", "g", "ml", "l", "ltr", "liter", "liters"}

	for _, su := range subUnits {
		if strings.HasSuffix(weight, su) {
			numStr := strings.TrimSuffix(weight, su)
			numStr = strings.TrimSpace(numStr)
			if numStr == "" {
				return 0, ""
			}
			val, err := strconv.ParseFloat(numStr, 64)
			if err != nil {
				return 0, ""
			}
			return val, su
		}
	}

	return 0, ""
}

// normalizeSubUnit maps variant sub-units to their canonical base form.
func normalizeSubUnit(sub string) string {
	switch sub {
	case "g":
		return "g"
	case "kg":
		return "kg"
	case "ml":
		return "ml"
	case "l", "ltr", "liter", "liters":
		return "l"
	default:
		return sub
	}
}

// normalizeBaseUnit maps the product's unit field to canonical base form.
func normalizeBaseUnit(unit string) string {
	switch strings.ToLower(strings.TrimSpace(unit)) {
	case "kg":
		return "kg"
	case "g":
		return "g"
	case "liters", "liter", "ltr", "l":
		return "l"
	case "ml":
		return "ml"
	case "pieces", "piece", "pcs", "pc", "units", "unit", "nos":
		return "pieces"
	default:
		return strings.ToLower(strings.TrimSpace(unit))
	}
}

// ConvertSubToBase converts a value from a sub-unit to its base unit.
// g → kg, ml → l, same unit → as-is.
func ConvertSubToBase(value float64, subUnit string) float64 {
	switch subUnit {
	case "g":
		return value / 1000.0
	case "ml":
		return value / 1000.0
	default:
		return value
	}
}

// CalculateEffectivePrice computes the price for a product based on its
// per-unit price and the actual weight/size of the specific variant.
//
// The product's Price field stores the cost per base unit (e.g., ₹120/kg).
// The weight field describes the specific variant (e.g., "500g").
// This function returns the effective price for that variant.
//
// Examples:
//
//	CalculateEffectivePrice(120, "500g", "kg")  → 60.00
//	CalculateEffectivePrice(120, "1kg", "kg")   → 120.00
//	CalculateEffectivePrice(120, "1.5kg", "kg") → 180.00
//	CalculateEffectivePrice(40, "500ml", "liters") → 20.00
//	CalculateEffectivePrice(40, "1L", "liters")  → 40.00
//	CalculateEffectivePrice(10, "", "pieces")     → 10.00
//	CalculateEffectivePrice(10, "", "")           → 10.00
func CalculateEffectivePrice(pricePerUnit float64, weight string, unit string) float64 {
	if pricePerUnit <= 0 {
		return pricePerUnit
	}

	baseUnit := normalizeBaseUnit(unit)

	// For pieces or empty/unknown units, no weight conversion applies
	if baseUnit == "pieces" || baseUnit == "" {
		return pricePerUnit
	}

	weightVal, subUnit := ParseWeight(weight)
	if weightVal <= 0 || subUnit == "" {
		return pricePerUnit
	}

	normSub := normalizeSubUnit(subUnit)

	// Convert the sub-unit value to the base unit
	var factor float64
	switch baseUnit {
	case "kg":
		// weight sub-unit must be g or kg
		if normSub == "g" {
			factor = weightVal / 1000.0
		} else if normSub == "kg" {
			factor = weightVal
		} else {
			return pricePerUnit
		}
	case "l":
		// weight sub-unit must be ml or l
		if normSub == "ml" {
			factor = weightVal / 1000.0
		} else if normSub == "l" {
			factor = weightVal
		} else {
			return pricePerUnit
		}
	default:
		return pricePerUnit
	}

	result := pricePerUnit * factor
	return math.Round(result*100) / 100 // round to 2 decimal places
}
