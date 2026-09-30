"""Check all distributed presets against the actual EA input declarations."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
inputs = set(re.findall(r'^input\s+\w+\s+(\w+)\s*=', (root/'Experts/AurumQuantEA.mq5').read_text(), re.M))
magics = set()
for path in sorted((root/'Presets').glob('*.set')):
    rows = [line.split('=', 1) for line in path.read_text().splitlines() if line and not line.startswith(';')]
    values = dict(rows)
    assert len(rows) == len(values), f'{path.name}: duplicate input'
    assert values.keys() == inputs, f'{path.name}: missing {inputs-values.keys()}, unknown {values.keys()-inputs}'
    assert values['OperatingMode'] == '0' and values['EnableOrderSubmission'] == 'false', path.name
    assert values['EnableBreakEven'] == 'false' and values['EnableTrailingStop'] == 'false', path.name
    assert values['MagicNumber'] not in magics, f'{path.name}: duplicate magic'
    magics.add(values['MagicNumber'])
    print(f'PASS: {path.name} ({len(values)} inputs, OBSERVE, submission OFF)')
