import { NextResponse } from 'next/server';
import { z } from 'zod';
import { createSupabaseServerClient } from '@/lib/supabase/server';

const requestSchema = z.object({
  fiscal_year: z.number(),
  receipt_number: z.string().optional(),
  category_id: z.number(),
  start_date: z.string(),
  end_date: z.string(),
  destination: z.string().optional(),
  location: z.string().optional(),
  activity_details: z.string(),
  expenses: z.array(
    z.object({
      expense_type: z.enum(['transportation', 'accommodation', 'per_diem', 'others']),
      route: z.string().optional(),
      transport_method: z.string().optional(),
      calculation_basis: z.string().optional(),
      amount: z.number(),
    }),
  ),
  receipt: z.object({
    payment_date: z.string(),
    payee: z.string(),
    title: z.string(),
    total_amount: z.number(),
    apportion_ratio: z.number(),
    reported_amount: z.number(),
    has_receipt: z.boolean(),
    receipt_image_path: z.string().optional(),
    no_receipt_reason: z.string().optional(),
  }),
  postages: z.array(
    z.object({
      item_type: z.enum(['stamp', 'postcard']),
      transaction_type: z.enum(['purchase', 'use']),
      transaction_date: z.string(),
      purpose: z.string().optional(),
      quantity: z.number(),
      price: z.number(),
    }),
  ),
  equipments: z.array(
    z.object({
      equipment_name: z.string(),
      quantity: z.number(),
      acquisition_date: z.string(),
      acquisition_price: z.number(),
    }),
  ),
});

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const payload = requestSchema.parse(body);
    const supabase = createSupabaseServerClient();

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return NextResponse.json({ error: '認証ユーザーを取得できませんでした。' }, { status: 401 });
    }

    const { data: activity, error: activityError } = await supabase
      .from('activities')
      .insert({
        user_id: user.id,
        fiscal_year: payload.fiscal_year,
        receipt_number: payload.receipt_number ?? null,
        category_id: payload.category_id,
        start_date: payload.start_date,
        end_date: payload.end_date,
        destination: payload.destination ?? null,
        location: payload.location ?? null,
        activity_details: payload.activity_details,
      })
      .select('id')
      .single();

    if (activityError || !activity) {
      return NextResponse.json({ error: activityError?.message ?? '活動登録に失敗しました。' }, { status: 400 });
    }

    const activityId = activity.id;

    if (payload.expenses.length > 0) {
      const { error } = await supabase.from('expenses').insert(
        payload.expenses.map((expense) => ({
          user_id: user.id,
          activity_id: activityId,
          expense_type: expense.expense_type,
          route: expense.route ?? null,
          transport_method: expense.transport_method ?? null,
          calculation_basis: expense.calculation_basis ?? null,
          amount: expense.amount,
        })),
      );
      if (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
      }
    }

    const { error: receiptError } = await supabase.from('receipts').insert({
      user_id: user.id,
      activity_id: activityId,
      payment_date: payload.receipt.payment_date,
      payee: payload.receipt.payee,
      title: payload.receipt.title,
      total_amount: payload.receipt.total_amount,
      apportion_ratio: payload.receipt.apportion_ratio,
      has_receipt: payload.receipt.has_receipt,
      receipt_image_path: payload.receipt.receipt_image_path ?? null,
      no_receipt_reason: payload.receipt.no_receipt_reason ?? null,
    });

    if (receiptError) {
      return NextResponse.json({ error: receiptError.message }, { status: 400 });
    }

    if (payload.postages.length > 0) {
      const { error } = await supabase.from('postages').insert(
        payload.postages.map((postage) => ({
          user_id: user.id,
          activity_id: activityId,
          item_type: postage.item_type,
          transaction_type: postage.transaction_type,
          transaction_date: postage.transaction_date,
          purpose: postage.purpose ?? null,
          quantity: postage.quantity,
          price: postage.price,
        })),
      );
      if (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
      }
    }

    if (payload.equipments.length > 0) {
      const { error } = await supabase.from('equipments').insert(
        payload.equipments.map((equipment) => ({
          user_id: user.id,
          activity_id: activityId,
          equipment_name: equipment.equipment_name,
          quantity: equipment.quantity,
          acquisition_date: equipment.acquisition_date,
          acquisition_price: equipment.acquisition_price,
        })),
      );
      if (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
      }
    }

    return NextResponse.json({ message: '活動記録を保存しました。' }, { status: 200 });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json({ error: '入力値が不正です。', details: error.flatten() }, { status: 400 });
    }
    return NextResponse.json({ error: error instanceof Error ? error.message : '予期せぬエラーです。' }, { status: 500 });
  }
}
