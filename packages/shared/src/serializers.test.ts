import { describe, expect, it } from 'vitest';
import {
  clinicClientLinkFromFirestore,
  clinicFromFirestore,
  clinicMemberFromFirestore,
  userProfileFromFirestore,
} from './serializers';

describe('clinicFromFirestore', () => {
  it('parses a full doc', () => {
    const c = clinicFromFirestore('yoshi-vet-care', {
      name: 'Yoshi Vet Care',
      isActive: true,
      brand: { primary: '#FA5119', accent: '#EA9374', logoWideUrl: 'u1', logoMarkUrl: 'u2' },
      contact: { phone: '210000000', address: 'Rua X', postalCode: '1000-001' },
      createdAt: 1_700_000_000_000,
      updatedAt: 1_700_000_001_000,
    });
    expect(c.id).toBe('yoshi-vet-care');
    expect(c.brand.primary).toBe('#FA5119');
    expect(c.brand.logoWideUrl).toBe('u1');
    expect(c.contact.phone).toBe('210000000');
    expect(c.createdAt.getTime()).toBe(1_700_000_000_000);
  });

  it('defaults missing brand/contact/isActive', () => {
    const c = clinicFromFirestore('x', { name: 'X' });
    expect(c.isActive).toBe(true);
    expect(c.brand.primary).toBe('');
    expect(c.brand.accent).toBeNull();
    expect(c.contact.phone).toBeNull();
  });
});

describe('clinicMemberFromFirestore', () => {
  it('parses owner and vet roles', () => {
    expect(clinicMemberFromFirestore({ role: 'owner' }).role).toBe('owner');
    expect(clinicMemberFromFirestore({ role: 'vet' }).role).toBe('vet');
  });
  it('unknown/missing role falls back to vet, missing active to true', () => {
    const m = clinicMemberFromFirestore({ role: 'receptionist' });
    expect(m.role).toBe('vet');
    expect(m.active).toBe(true);
  });
});

describe('clinicClientLinkFromFirestore', () => {
  it('parses statuses and dates', () => {
    const l = clinicClientLinkFromFirestore({
      clientId: 'u1',
      clientName: 'Ana',
      clinicName: 'Yoshi',
      status: 'active',
      addedBy: 'v1',
      addedByName: 'Dra. S',
      addedAt: 1000,
      respondedAt: 2000,
    });
    expect(l.status).toBe('active');
    expect(l.addedAt.getTime()).toBe(1000);
    expect(l.respondedAt?.getTime()).toBe(2000);
  });
  it('unknown status falls back to pending, missing respondedAt to null', () => {
    const l = clinicClientLinkFromFirestore({ status: 'weird' });
    expect(l.status).toBe('pending');
    expect(l.respondedAt).toBeNull();
  });
});

describe('userProfileFromFirestore clinic arrays', () => {
  it('reads memberOf/clientOf and defaults to empty', () => {
    const p = userProfileFromFirestore('u', { userType: 1, memberOf: ['a', 'b'], clientOf: ['c'] });
    expect(p.memberOf).toEqual(['a', 'b']);
    expect(p.clientOf).toEqual(['c']);
    const q = userProfileFromFirestore('u', { userType: 0 });
    expect(q.memberOf).toEqual([]);
    expect(q.clientOf).toEqual([]);
  });
});
