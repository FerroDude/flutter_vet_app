import { useClinicClients } from './clinicService';

/**
 * Active clients of the clinic, sorted by name. Thin wrapper kept for the
 * existing call sites — the pending links live in `useClinicClients` directly.
 */
export function useClients(clinicId: string) {
  const { clients, loading, error } = useClinicClients(clinicId);
  return { clients, loading, error };
}
