import Link from 'next/link';

export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-5xl flex-col items-start justify-center p-6">
      <h1 className="text-3xl font-bold text-slate-900">南国市議会 政務活動費申請システム</h1>
      <p className="mt-3 text-slate-700">1回の活動を1度入力するだけで、各帳票に自動配賦される入力画面です。</p>
      <Link
        href="/activities/new"
        className="mt-6 inline-flex rounded-lg bg-slate-900 px-4 py-2 font-medium text-white hover:bg-slate-700"
      >
        活動記録入力へ
      </Link>
    </main>
  );
}
