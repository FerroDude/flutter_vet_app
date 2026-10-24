import { createContext, useCallback, useContext, useRef, useState, type ReactNode } from 'react';
import { Dialog } from './Dialog';
import { Button } from './Button';
import { t } from '@/i18n';

interface ConfirmOptions {
  title: string;
  description?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  /** Red confirm button for irreversible actions. */
  danger?: boolean;
}

type ConfirmFn = (o: ConfirmOptions) => Promise<boolean>;

const ConfirmContext = createContext<ConfirmFn | null>(null);

/** One styled confirmation dialog for the whole app: `if (await confirm({...}))`. */
export function ConfirmProvider({ children }: { children: ReactNode }) {
  const [opts, setOpts] = useState<ConfirmOptions | null>(null);
  const resolver = useRef<(v: boolean) => void>();

  const confirm = useCallback<ConfirmFn>(
    (o) =>
      new Promise<boolean>((resolve) => {
        resolver.current = resolve;
        setOpts(o);
      }),
    [],
  );

  const close = (v: boolean) => {
    resolver.current?.(v);
    resolver.current = undefined;
    setOpts(null);
  };

  return (
    <ConfirmContext.Provider value={confirm}>
      {children}
      <Dialog
        open={opts !== null}
        onClose={() => close(false)}
        title={opts?.title ?? ''}
        description={opts?.description}
        footer={
          <>
            <Button variant="outline" onClick={() => close(false)}>
              {opts?.cancelLabel ?? t('common.cancel')}
            </Button>
            <Button variant={opts?.danger ? 'destructive' : 'primary'} onClick={() => close(true)}>
              {opts?.confirmLabel ?? t('common.confirm')}
            </Button>
          </>
        }
      />
    </ConfirmContext.Provider>
  );
}

export function useConfirm(): ConfirmFn {
  const ctx = useContext(ConfirmContext);
  if (!ctx) throw new Error('useConfirm must be used within <ConfirmProvider>');
  return ctx;
}
