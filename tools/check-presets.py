"""Check all distributed presets against the actual EA input declarations."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
ea_text = (root/'Experts/AurumQuantEA.mq5').read_text()
inputs = set(re.findall(r'^input\s+\w+\s+(\w+)\s*=', ea_text, re.M))
defaults = dict(re.findall(r'^input\s+\w+\s+(\w+)\s*=\s*([^;]+);', ea_text, re.M))
default_magic = int(defaults['MagicNumber']); default_base = int(defaults['PortfolioMagicBase']); default_span = int(defaults['PortfolioMagicSpan'])
assert default_base <= default_magic < default_base + default_span, 'EA default MagicNumber is outside its portfolio group'
magics = set()
portfolio_group = None
for path in sorted((root/'Presets').glob('*.set')):
    rows = [line.split('=', 1) for line in path.read_text().splitlines() if line and not line.startswith(';')]
    values = dict(rows)
    assert len(rows) == len(values), f'{path.name}: duplicate input'
    assert values.keys() == inputs, f'{path.name}: missing {inputs-values.keys()}, unknown {values.keys()-inputs}'
    assert values['OperatingMode'] == '0' and values['EnableOrderSubmission'] == 'false', path.name
    assert values['EnableBreakEven'] == 'false' and values['EnableTrailingStop'] == 'false', path.name
    assert values['MagicNumber'] not in magics, f'{path.name}: duplicate magic'
    magics.add(values['MagicNumber'])
    magic = int(values['MagicNumber']); base = int(values['PortfolioMagicBase']); span = int(values['PortfolioMagicSpan'])
    assert base > 0 and span > 0 and base <= magic < base + span, f'{path.name}: magic outside portfolio group'
    group = (base, span)
    if portfolio_group is None: portfolio_group = group
    assert group == portfolio_group, f'{path.name}: inconsistent portfolio group'
    assert float(values['MaxPortfolioRiskPercent']) >= float(values['RiskPercent']) > 0, f'{path.name}: invalid portfolio risk cap'
    assert int(values['MaxPortfolioPositions']) >= 1, f'{path.name}: invalid portfolio position cap'
    print(f'PASS: {path.name} ({len(values)} inputs, OBSERVE, submission OFF, portfolio group {base}+{span})')
