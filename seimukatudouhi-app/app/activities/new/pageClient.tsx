'use client';

import { useState } from 'react';
import ActivityForm, { ActivitySubmitPayload } from '@/components/ActivityForm';

export default function ActivityFormPageClient() {
  const [message, setMessage] = useState<string | null>(null);

  const onSubmitActivity = async (payload: ActivitySubmitPayload) => {
    setMessage(null);

    const response = await fetch('/api/activities', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    const data = (await response.json()) as { error?: string; message?: string };

    if (!response.ok) {
      throw new Error(data.error ?? '保存に失敗しました。');
    }

    setMessage(data.message ?? '保存しました。');
  };

  return (
    <main className="mx-auto w-full max-w-6xl p-4 md:p-8">
      <header className="mb-6">
        <h1 className="text-2xl font-bold">活動記録入力（1トランザクション）</h1>
        <p className="mt-2 text-sm text-slate-700">活動・経費・証憑・特殊入力を一画面で登録します。</p>
      </header>

      {message && <p className="mb-4 rounded border border-green-200 bg-green-50 p-3 text-sm text-green-700">{message}</p>}

      <ActivityForm onSubmitActivity={onSubmitActivity} />
    </main>
  );
}
