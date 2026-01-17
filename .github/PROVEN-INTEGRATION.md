# proven Integration Plan

This document outlines the recommended [proven](https://github.com/hyperpolymath/proven) modules for Vexometer.

## Recommended Modules

| Module | Purpose | Priority |
|--------|---------|----------|
| SafeMath | Arithmetic that cannot overflow for irritation metric calculations | High |
| SafeFloat | IEEE 754 floating point safety for surface analysis measurements | High |

## Integration Notes

Vexometer as an irritation surface analyser requires precise numerical computation:

- **SafeMath** ensures all metric calculations are overflow-safe. When aggregating irritation scores across large datasets, integer overflow could silently corrupt results. SafeMath's `add_checked` and `mul_checked` detect overflow before it happens.

- **SafeFloat** handles floating-point edge cases that can corrupt analysis results. The `FiniteFloat` type guarantees values are neither NaN nor Inf, `safeDiv` prevents NaN from division, and `safeSqrt` ensures non-negative inputs. For statistical analysis of irritation surfaces, these guarantees prevent silent numerical corruption.

The combination ensures Vexometer's measurements are mathematically correct, with explicit handling of all edge cases that could produce invalid results.

## Related

- [proven library](https://github.com/hyperpolymath/proven)
- [Idris 2 documentation](https://idris2.readthedocs.io/)
