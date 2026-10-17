import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Toaster } from 'sonner';
import { RootGate } from '@/app/RootGate';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        {/* Phase 2: state-driven gate (auth + role routing). Full URL route tree lands later. */}
        <Route path="/*" element={<RootGate />} />
      </Routes>
      <Toaster richColors position="top-center" />
    </BrowserRouter>
  );
}
