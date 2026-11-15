import './globals.css';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'Jemba Business Manager', description: 'Business operations, sales, inventory and accounting for Jemba Supply and Solutions Nigeria.', manifest: '/manifest.webmanifest' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="en"><body>{children}</body></html>; }
