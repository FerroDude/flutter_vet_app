import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Toaster } from 'sonner';
import { RootGate } from '@/app/RootGate';
import { ConfirmProvider } from '@/components/ui/Confirm';

export default function App() {
  return (
    <BrowserRouter basename={import.meta.env.BASE_URL}>
      <ConfirmProvider>
        <Routes>
          <Route path="/*" element={<RootGate />} />
        </Routes>
      </ConfirmProvider>
      <Toaster richColors position="top-center" />
    </BrowserRouter>
  );
}
