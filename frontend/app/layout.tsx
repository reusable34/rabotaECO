import type { Metadata } from 'next';
import './globals.scss';
import Navigation from './components/Navigation';

export const metadata: Metadata = {
  title: 'Личный кабинет клиента по экологии',
  description: 'Управление экологическими требованиями',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ru">
      <body>
        <Navigation />
        <div className="container">
          {children}
        </div>
      </body>
    </html>
  );
}

