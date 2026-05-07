import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: '南国市議会 政務活動費申請',
  description: '1トランザクション入力で帳票自動生成する申請システム',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
