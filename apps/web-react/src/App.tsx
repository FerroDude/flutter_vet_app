import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Toaster } from 'sonner';
import { RootGate } from '@/app/RootGate';
import { ConfirmProvider } from '@/components/ui/Confirm';
import { PetTagPage } from '@/features/pets/PetTagPage';

export default function App() {
  return (
    <BrowserRouter basename={import.meta.env.BASE_URL}>
      <ConfirmProvider>
        <Routes>
          {/* Public pet-tag QR route: no login required. */}
          <Route path="/t/:petId" element={<PetTagPage />} />
          <Route path="/*" element={<RootGate />} />
        </Routes>
      </ConfirmProvider>
      <Toaster richColors position="top-center" />
    </BrowserRouter>
  );
}
