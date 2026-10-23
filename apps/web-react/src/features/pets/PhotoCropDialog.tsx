import { useEffect, useRef, useState } from 'react';
import { toast } from 'sonner';
import { Dialog } from '@/components/ui/Dialog';
import { Button } from '@/components/ui/Button';

const VIEW = 280;
const OUT = 512;
const MIN_ZOOM = 1;
const MAX_ZOOM = 4;

interface PhotoCropDialogProps {
  file: File | null;
  onCancel: () => void;
  onConfirm: (blob: Blob) => void;
}

const clampNum = (v: number, min: number, max: number) => Math.min(max, Math.max(min, v));

/** Drag + zoom cropper that exports a square JPEG blob for the pet avatar. */
export function PhotoCropDialog({ file, onCancel, onConfirm }: PhotoCropDialogProps) {
  const viewRef = useRef<HTMLDivElement>(null);
  const imgRef = useRef<HTMLImageElement>(null);
  const dragRef = useRef<{ px: number; py: number; x: number; y: number } | null>(null);

  const [url, setUrl] = useState<string | null>(null);
  const [nat, setNat] = useState<{ w: number; h: number } | null>(null);
  const [zoom, setZoom] = useState(MIN_ZOOM);
  const [off, setOff] = useState({ x: 0, y: 0 });

  // Object URL for the picked file; also resets crop state for the new image.
  useEffect(() => {
    setNat(null);
    setZoom(MIN_ZOOM);
    setOff({ x: 0, y: 0 });
    if (!file) {
      setUrl(null);
      return;
    }
    const u = URL.createObjectURL(file);
    setUrl(u);
    return () => URL.revokeObjectURL(u);
  }, [file]);

  const base = nat ? VIEW / Math.min(nat.w, nat.h) : 0;
  const dispW = nat ? nat.w * base * zoom : 0;
  const dispH = nat ? nat.h * base * zoom : 0;

  const clampOff = (o: { x: number; y: number }, dw: number, dh: number) => ({
    x: clampNum(o.x, VIEW - dw, 0),
    y: clampNum(o.y, VIEW - dh, 0),
  });

  // Zoom around the viewport centre, then re-clamp so the image keeps covering.
  const applyZoom = (nzRaw: number) => {
    if (!nat) return;
    const nz = clampNum(nzRaw, MIN_ZOOM, MAX_ZOOM);
    const k = nz / zoom;
    const dw = nat.w * base * nz;
    const dh = nat.h * base * nz;
    setZoom(nz);
    setOff((o) =>
      clampOff(
        { x: VIEW / 2 - (VIEW / 2 - o.x) * k, y: VIEW / 2 - (VIEW / 2 - o.y) * k },
        dw,
        dh,
      ),
    );
  };

  // Non-passive wheel listener so preventDefault stops the page scrolling.
  useEffect(() => {
    const el = viewRef.current;
    if (!el || !file) return;
    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      applyZoomRef.current(zoomRef.current + (e.deltaY > 0 ? -0.1 : 0.1));
    };
    el.addEventListener('wheel', onWheel, { passive: false });
    return () => el.removeEventListener('wheel', onWheel);
  }, [file, url]);

  const zoomRef = useRef(zoom);
  zoomRef.current = zoom;
  const applyZoomRef = useRef(applyZoom);
  applyZoomRef.current = applyZoom;

  const confirm = () => {
    const img = imgRef.current;
    if (!img || !nat) return;
    const s = base * zoom;
    const sx = -off.x / s;
    const sy = -off.y / s;
    const sSize = VIEW / s;
    const canvas = document.createElement('canvas');
    canvas.width = OUT;
    canvas.height = OUT;
    canvas.getContext('2d')!.drawImage(img, sx, sy, sSize, sSize, 0, 0, OUT, OUT);
    canvas.toBlob(
      (b) => (b ? onConfirm(b) : toast.error('Não foi possível processar a imagem.')),
      'image/jpeg',
      0.85,
    );
  };

  return (
    <Dialog
      open={file !== null}
      onClose={onCancel}
      title="Ajustar foto"
      description="Arraste para posicionar e use o zoom."
      footer={
        <>
          <Button variant="outline" onClick={onCancel}>
            Cancelar
          </Button>
          <Button onClick={confirm} disabled={!nat}>
            Usar foto
          </Button>
        </>
      }
    >
      <div
        ref={viewRef}
        className="relative mx-auto cursor-grab touch-none select-none overflow-hidden rounded-full bg-secondary ring-1 ring-border"
        style={{ width: VIEW, height: VIEW }}
        onPointerDown={(e) => {
          e.currentTarget.setPointerCapture(e.pointerId);
          dragRef.current = { px: e.clientX, py: e.clientY, x: off.x, y: off.y };
        }}
        onPointerMove={(e) => {
          const d = dragRef.current;
          if (!d) return;
          setOff(clampOff({ x: d.x + e.clientX - d.px, y: d.y + e.clientY - d.py }, dispW, dispH));
        }}
        onPointerUp={() => (dragRef.current = null)}
        onPointerCancel={() => (dragRef.current = null)}
      >
        {url && (
          <img
            ref={imgRef}
            src={url}
            alt=""
            draggable={false}
            onLoad={(e) => {
              const img = e.currentTarget;
              const w = img.naturalWidth;
              const h = img.naturalHeight;
              const b = VIEW / Math.min(w, h);
              setNat({ w, h });
              setZoom(MIN_ZOOM);
              setOff({ x: (VIEW - w * b) / 2, y: (VIEW - h * b) / 2 });
            }}
            className="absolute max-w-none"
            style={{ left: off.x, top: off.y, width: dispW || undefined, height: dispH || undefined }}
          />
        )}
      </div>
      <input
        type="range"
        min={MIN_ZOOM}
        max={MAX_ZOOM}
        step={0.01}
        value={zoom}
        aria-label="Zoom"
        onChange={(e) => applyZoom(Number(e.target.value))}
        className="mt-4 w-full accent-[hsl(var(--primary))]"
      />
    </Dialog>
  );
}

