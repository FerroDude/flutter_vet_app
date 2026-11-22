import { describe, expect, it } from 'vitest';
import {
  applyBrand,
  brandVars,
  contrastRatio,
  hexToHslTriple,
  YOSHI_CLINIC,
} from './brand';

describe('hexToHslTriple', () => {
  it('converts brand hexes to H S% L% triples', () => {
    expect(hexToHslTriple('#0E7C72')).toBe('175 80% 27%');
    expect(hexToHslTriple('#FA5119')).toBe('15 96% 54%');
    expect(hexToHslTriple('#FFFFFF')).toBe('0 0% 100%');
    expect(hexToHslTriple('#000000')).toBe('0 0% 0%');
  });
});

describe('contrastRatio', () => {
  it('white on black is 21', () => {
    expect(contrastRatio('#FFFFFF', '#000000')).toBeCloseTo(21, 0);
  });
  it('white on VetTempo teal is ~5.0', () => {
    expect(contrastRatio('#FFFFFF', '#0E7C72')).toBeGreaterThan(4.9);
    expect(contrastRatio('#FFFFFF', '#0E7C72')).toBeLessThan(5.2);
  });
});

describe('brandVars', () => {
  it('Yoshi orange keeps a white primary-foreground and 95% primary-light', () => {
    const vars = brandVars(YOSHI_CLINIC.brand);
    expect(vars['--primary']).toBe('15 96% 54%');
    expect(vars['--ring']).toBe(vars['--primary']);
    expect(vars['--primary-light']).toBe('15 96% 95%');
    expect(vars['--primary-foreground']).toBe('0 0% 100%');
    expect(vars['--accent']).toBe('16 74% 69%');
  });

  it('light primaries fall back to ink foreground', () => {
    const vars = brandVars({ primary: '#F6E27A' });
    expect(vars['--primary-foreground']).toBe('195 55% 13%');
  });

  it('omits --accent when the brand has none', () => {
    expect(brandVars({ primary: '#0E7C72' })).not.toHaveProperty('--accent');
  });
});

describe('applyBrand', () => {
  it('sets then clears the inline vars and theme-color', () => {
    const meta = document.createElement('meta');
    meta.setAttribute('name', 'theme-color');
    meta.setAttribute('content', '#0E7C72');
    document.head.appendChild(meta);
    const style = document.documentElement.style;

    applyBrand(YOSHI_CLINIC.brand);
    expect(style.getPropertyValue('--primary')).toBe('15 96% 54%');
    expect(style.getPropertyValue('--ring')).toBe('15 96% 54%');
    expect(style.getPropertyValue('--primary-light')).toBe('15 96% 95%');
    expect(style.getPropertyValue('--primary-foreground')).toBe('0 0% 100%');
    expect(style.getPropertyValue('--accent')).toBe('16 74% 69%');
    expect(meta.getAttribute('content')).toBe('#FA5119');

    applyBrand(null);
    for (const v of ['--primary', '--ring', '--primary-light', '--primary-foreground', '--accent']) {
      expect(style.getPropertyValue(v)).toBe('');
    }
    expect(meta.getAttribute('content')).toBe('#0E7C72');
    document.head.removeChild(meta);
  });
});
