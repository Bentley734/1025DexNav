# Validation of 0.2.1

On 2026-10-07, Lua 5.3 and LuaJIT 2.1 both passed 693 all-game assertions
including the engine's actual keyboard/controller Input implementation and its
pre-promotion hook order. These reproduce the SELECT timing defect in 0.2.0.
The six GB game cases verify opening, held SELECT, registration, selection,
search handoff, closing, absence of sprite drawing, native integer font positions
and right-edge text bounds. Gen 3 terrain/policy/UI regressions also passed
344,307 assertions in each runtime. Every bundled Lua file compiled.

Graphics calls are captured by test fixtures, rather than visually observed in
an active game. The unchanged identity and move-policy validation from 0.2.0
is recorded below.

# Validation of 0.2.0



Validated on 2026-10-07 with the local Gen1Recomp 0.3.54 sources and

1025Dex 1.2.15 data, under Lua 5.3 and LuaJIT 2.1.



| Suite | Assertions per runtime |

| --- | ---: |

| All 11 games and actual 1025Dex species-number export | 243 |

| 1,025 species, levels 1–100, FRLG/RSE move and PP parity | 2,767,503 |

| Real encounter policy, all 17 generation selections and terrain/UI handoff | 344,307 |

| Independent generator boundaries and native-stat potential | 14 |



Both runtimes also compiled every bundled Lua source and accepted the manifest

through the engine's native validator with all 11 games and Gen 2 compatibility.

The policy suite traversed 85,275 FR/LG/Hoenn encounter entries per runtime.



Engine data/world interfaces and GB mon constructors are real source modules;

active runtime, graphics, imported ROM maps and battle transitions use controlled

fixtures. No live in-game visual verification is claimed. Test inputs and exact

assertions are bundled in `tests/` for repeatable checking.

