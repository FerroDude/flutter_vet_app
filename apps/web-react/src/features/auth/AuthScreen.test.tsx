import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { AuthScreen } from './AuthScreen';

vi.mock('@/lib/firebase', () => ({ auth: {} }));

describe('AuthScreen', () => {
  it('offers sign-in and password reset, not open registration', () => {
    render(<AuthScreen />);
    expect(screen.getByRole('button', { name: 'Entrar' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Esqueceu-se da palavra-passe?' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Registar' })).not.toBeInTheDocument();
    expect(screen.queryByText('Criar conta')).not.toBeInTheDocument();
  });
});
