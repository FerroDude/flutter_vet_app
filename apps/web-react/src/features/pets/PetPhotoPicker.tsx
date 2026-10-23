import { useEffect, useRef, useState } from 'react';
import { PawPrint } from 'lucide-react';
import { Button } from '@/components/ui/Button';

interface PetPhotoPickerProps {
  photoUrl: string | null;
  file: File | null;
  name: string;
  onPick: (f: File) => void;
  onRemove: () => void;
  disabled?: boolean;
}

/** 96px photo preview + pick/remove controls for the pet form. */
export function PetPhotoPicker({ photoUrl, file, name, onPick, onRemove, disabled }: PetPhotoPickerProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [objectUrl, setObjectUrl] = useState<string | null>(null);

  useEffect(() => {
    if (!file) {
      setObjectUrl(null);
      return;
    }
    const url = URL.createObjectURL(file);
    setObjectUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  const src = objectUrl ?? photoUrl;

  return (
    <div className="flex items-center gap-4">
      <div className="flex h-24 w-24 shrink-0 items-center justify-center overflow-hidden rounded-(--radius-lg) bg-primary-light">
        {src ? (
          <img src={src} alt={name} className="h-full w-full object-cover" />
        ) : name.trim() ? (
          <span className="font-display text-4xl font-semibold leading-none text-primary/70">
            {name.trim().charAt(0).toUpperCase()}
          </span>
        ) : (
          <PawPrint size={32} className="text-primary/70" />
        )}
      </div>
      <div className="space-y-2">
        <div className="flex flex-wrap gap-2">
          <Button type="button" variant="outline" disabled={disabled} onClick={() => inputRef.current?.click()}>
            {src ? 'Mudar foto' : 'Escolher foto'}
          </Button>
          {src && (
            <Button type="button" variant="ghost" disabled={disabled} onClick={onRemove}>
              Remover
            </Button>
          )}
        </div>
        <p className="text-xs text-muted-foreground">JPG ou PNG. A foto é reduzida automaticamente.</p>
      </div>
      <input
        ref={inputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => {
          const f = e.target.files?.[0];
          e.target.value = '';
          if (f) onPick(f);
        }}
      />
    </div>
  );
}
