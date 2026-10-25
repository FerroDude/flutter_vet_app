import { useEffect, useRef, useState } from 'react';
import { toast } from 'sonner';
import { QRCodeCanvas } from 'qrcode.react';
import { Download, Printer } from 'lucide-react';
import { Dialog } from '@/components/ui/Dialog';
import { Button } from '@/components/ui/Button';
import { getPetTag, syncPetTag, ensurePetTagAsVet } from '@/lib/petTagService';
import { errorMessage } from '@/lib/format';
import { type Pet } from '@/lib/petService';
import { t } from '@/i18n';

interface Props {
  open: boolean;
  onClose: () => void;
  /** The pet OWNER's uid (clientId in vet view). */
  uid: string;
  pet: Pet;
  /** true = owner (contact opt-in shown); false = vet (pet fields only). */
  ownerView: boolean;
  ownerName?: string;
  ownerPhone?: string;
}

/** QR-code dialog on the pet page. Owner: syncs the tag + contact opt-in.
 *  Vet: creates/refreshes the pet fields only — the contact choice stays
 *  the owner's. */
export function PetTagDialog({ open, onClose, uid, pet, ownerView, ownerName = '', ownerPhone = '' }: Props) {
  const url = `${window.location.origin}${import.meta.env.BASE_URL}t/${pet.id}`;
  const [showContact, setShowContact] = useState(false);
  const qrRef = useRef<HTMLDivElement>(null);

  const sync = async (show: boolean) => {
    try {
      await syncPetTag(uid, pet, { displayName: ownerName, phone: ownerPhone }, show);
    } catch (e) {
      toast.error(errorMessage(e));
    }
  };

  // On open: owner restores the stored showContact choice then writes the tag;
  // the vet just creates/refreshes the pet fields.
  useEffect(() => {
    if (!open) return;
    void (async () => {
      if (!ownerView) {
        try {
          await ensurePetTagAsVet(uid, pet);
        } catch (e) {
          toast.error(errorMessage(e));
        }
        return;
      }
      let show = false;
      try {
        show = (await getPetTag(pet.id))?.showContact ?? false;
      } catch {
        /* first time or no access */
      }
      setShowContact(show);
      void sync(show);
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, pet.id]);

  const togglePhone = (show: boolean) => {
    setShowContact(show);
    void sync(show);
  };

  const dataUrl = () =>
    qrRef.current?.querySelector('canvas')?.toDataURL('image/png') ?? null;

  const download = () => {
    const d = dataUrl();
    if (!d) return;
    const a = document.createElement('a');
    a.href = d;
    a.download = `${pet.name}-qr.png`;
    a.click();
  };

  const print = () => {
    const d = dataUrl();
    if (!d) return;
    const w = window.open('', '_blank', 'width=420,height=560');
    if (!w) return;
    w.document.write(
      `<!doctype html><html><body style="margin:0;display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:100vh">` +
        `<img src="${d}" style="width:320px" onload="window.print()">` +
        `<p style="font-family:sans-serif;font-size:22px;font-weight:700">${pet.name.replace(/</g, '&lt;')}</p>` +
        `</body></html>`,
    );
    w.document.close();
  };

  return (
    <Dialog open={open} onClose={onClose} title={t('tag.title')} className="max-w-sm">
      <div className="flex flex-col items-center gap-4">
        <div ref={qrRef} className="rounded-(--radius-md) bg-white p-3">
          <QRCodeCanvas value={url} size={768} style={{ width: 208, height: 208 }} marginSize={2} level="H" fgColor="#000000" bgColor="#ffffff" />
        </div>
        <p className="break-words text-center font-medium text-foreground">{pet.name}</p>

        {ownerView && (
          <>
            <label className="inline-flex items-center gap-2 self-start text-sm text-muted-foreground">
              <input
                type="checkbox"
                checked={showContact}
                disabled={!ownerPhone}
                onChange={(e) => togglePhone(e.target.checked)}
                className="h-4 w-4 accent-[hsl(var(--primary))]"
              />
              {t('tag.showContact')}
            </label>
            {!ownerPhone && (
              <p className="-mt-2 self-start text-xs text-muted-foreground">{t('tag.noPhone')}</p>
            )}
          </>
        )}

        <div className="flex w-full justify-end gap-2">
          <Button variant="outline" onClick={download}>
            <Download size={16} /> {t('tag.download')}
          </Button>
          <Button variant="outline" onClick={print}>
            <Printer size={16} /> {t('tag.print')}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}
