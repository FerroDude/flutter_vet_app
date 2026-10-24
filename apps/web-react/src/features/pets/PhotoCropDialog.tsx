import { useEffect, useRef, useState } from 'react';
import { toast } from 'sonner';
import { Dialog } from '@/components/ui/Dialog';
import { Button } from '@/components/ui/Button';
import { t } from '@/i18n';

const VIEW = 280;
const OUT = 512;
const MAX_SRC = 2048;
const MIN_ZOOM = 1;
const MAX_ZOOM = 4;

interface PhotoCropDialogProps {
  file: File | null;
  onCancel: () => void;
  onConfirm: (blob: Blob) => void;
}

const clampNum = (v: number, min: number, max: number) => Math.min(max, Math.max(min, v));

/** Drag + zoom cropper that exports a square JPEG blob for the pet avatar.
 *  The file is normalised once (EXIF orientation applied, capped at 2048px)
 *  into a canvas; the preview shows an object URL of that same canvas so
 *  displayed pixels and crop math always agree. */
export function PhotoCropDialog({ file, onCancel, onConfirm }: PhotoCropDialogProps) {
  const viewRef = useRef<HTMLDivElement>(null);
  const srcRef = useRef<HTMLCanvasElement | null>(null);
  const dragRef = useRef<{ px: number; py: number; x: number; y: number } | null>(null);

  const [url, setUrl] = useState<string | null>(null);
  const [nat, setNat] = useState<{ w: number; h: number } | null>(null);
  const [zoom, setZoom] = useState(MIN_ZOOM);
  const [off, setOff] = useState({ x: 0, y: 0 });

  // Normalise the picked file once; resets crop state for the new image.
  useEffect(() => {
    setNat(null);
    setZoom(MIN_ZOOM);
    setOff({ x: 0, y: 0 });
    setUrl(null);
    srcRef.current = null;
    if (!file) return;

    let cancelled = false;
    let objUrl: string | null = null;
    void (async () => {
      try {
        const bmp = await createImageBitmap(file, { imageOrientation: 'from-image' });
        const scale = Math.min(1, MAX_SRC / Math.max(bmp.width, bmp.height));
        const canvas = document.createElement('canvas');
        canvas.width = Math.round(bmp.width * scale);
        canvas.height = Math.round(bmp.height * scale);
        canvas.getContext('2d')!.drawImage(bmp, 0, 0, canvas.width, canvas.height);
        bmp.close();
        if (cancelled) return;
        srcRef.current = canvas;

        canvas.toBlob(
          (b) => {
            if (!b || cancelled) return;
            objUrl = URL.createObjectURL(b);
            setUrl(objUrl);
          },
          'image/jpeg',
          0.92,
        );

        const b = VIEW / Math.min(canvas.width, canvas.height);
        setNat({ w: canvas.width, h: canvas.height });
        setZoom(MIN_ZOOM);
        setOff({ x: (VIEW - canvas.width * b) / 2, y: (VIEW - canvas.height * b) / 2 });
      } catch {
        if (!cancelled) {
          toast.error(t('pets.crop.openFailed'));
          onCancel();
        }
      }
    })();

    return () => {
      cancelled = true;
      if (objUrl) URL.revokeObjectURL(objUrl);
    };
    // onCancel is intentionally not a dep: the parent passes an inline fn.
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

  const zoomRef = useRef(zoom);
  zoomRef.current = zoom;
  const applyZoomRef = useRef(applyZoom);
  applyZoomRef.current = applyZoom;

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

  const confirm = () => {
    const src = srcRef.current;
    if (!src || !nat) return;
    const s = base * zoom;
    const sx = -off.x / s;
    const sy = -off.y / s;
    const sSize = VIEW / s;
    const canvas = document.createElement('canvas');
    canvas.width = OUT;
    canvas.height = OUT;
    canvas.getContext('2d')!.drawImage(src, sx, sy, sSize, sSize, 0, 0, OUT, OUT);
    canvas.toBlob(
      (b) => (b ? onConfirm(b) : toast.error(t('pets.crop.processFailed'))),
      'image/jpeg',
      0.85,
    );
  };

  return (
    <Dialog
      open={file !== null}
      onClose={onCancel}
      title={t('pets.crop.title')}
      description={t('pets.crop.desc')}
      footer={
        <>
          <Button variant="outline" onClick={onCancel}>
            {t('common.cancel')}
          </Button>
          <Button onClick={confirm} disabled={!nat}>
            {t('pets.crop.use')}
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
        {url && dispW > 0 && (
          <img
            src={url}
            alt=""
            draggable={false}
            className="absolute max-w-none"
            style={{ left: off.x, top: off.y, width: dispW, height: dispH }}
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
