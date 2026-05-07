'use client';

import { useMemo, useState } from 'react';
import { useFieldArray, useForm } from 'react-hook-form';
import { z } from 'zod';
import { zodResolver } from '@hookform/resolvers/zod';
import { createClient } from '@supabase/supabase-js';

const NG_WORDS = ['koden', 'konshinkai', 'shaken', 'sports newspaper', '香典', '懇親会', '車検', 'スポーツ新聞'];

const CATEGORY_OPTIONS = [
  { id: 1, label: '1. Research' },
  { id: 2, label: '2. Training' },
  { id: 3, label: '3. Public Relations' },
  { id: 4, label: '4. Public Hearing' },
  { id: 5, label: '5. Petition Activities' },
  { id: 6, label: '6. Meeting Expenses' },
  { id: 7, label: '7. Material Creation' },
  { id: 8, label: '8. Material Purchase' },
] as const;

const expenseSchema = z.object({
  expenseType: z.enum(['transportation', 'accommodation', 'per_diem', 'others']),
  route: z.string().trim().optional(),
  transportMethod: z.string().trim().optional(),
  calculationBasis: z.string().trim().optional(),
  amount: z.coerce.number().min(0, 'Amount must be >= 0'),
});

const postageSchema = z.object({
  itemType: z.enum(['stamp', 'postcard']),
  transactionType: z.enum(['purchase', 'use']),
  transactionDate: z.string().min(1, 'Date is required'),
  purpose: z.string().trim().optional(),
  quantity: z.coerce.number().int().positive('Quantity must be > 0'),
  price: z.coerce.number().min(0, 'Price must be >= 0'),
});

const equipmentSchema = z.object({
  equipmentName: z.string().trim().min(1, 'Equipment name is required'),
  quantity: z.coerce.number().int().positive('Quantity must be > 0'),
  acquisitionDate: z.string().min(1, 'Acquisition date is required'),
  acquisitionPrice: z.coerce.number().min(0, 'Acquisition price must be >= 0'),
});

const containsNgWord = (value: string) => {
  const normalized = value.toLowerCase();
  return NG_WORDS.some((word) => normalized.includes(word.toLowerCase()));
};

const activitySchema = z
  .object({
    fiscalYear: z.coerce.number().int().min(2000).max(9999),
    receiptNumber: z.string().trim().optional(),
    categoryId: z.coerce.number().int().min(1).max(8),
    startDate: z.string().min(1, 'Start date is required'),
    endDate: z.string().min(1, 'End date is required'),
    destination: z.string().trim().optional(),
    location: z.string().trim().optional(),
    activityDetails: z.string().trim().min(1, 'Activity details are required'),
    expenses: z.array(expenseSchema).min(1, 'At least one expense is required'),
    paymentDate: z.string().min(1, 'Payment date is required'),
    payee: z.string().trim().min(1, 'Payee is required'),
    title: z.string().trim().min(1, 'Title is required'),
    apportionRatioPercent: z.coerce.number().min(1, 'Ratio must be >= 1').max(100, 'Ratio must be <= 100'),
    hasReceipt: z.boolean(),
    receiptImagePath: z.string().trim().optional(),
    noReceiptReason: z.string().trim().optional(),
    postages: z.array(postageSchema).optional().default([]),
    equipments: z.array(equipmentSchema).optional().default([]),
  })
  .refine((data) => !containsNgWord(data.activityDetails), {
    path: ['activityDetails'],
    message: 'Contains prohibited keyword',
  })
  .refine((data) => !containsNgWord(data.payee), {
    path: ['payee'],
    message: 'Contains prohibited keyword',
  })
  .refine((data) => !containsNgWord(data.title), {
    path: ['title'],
    message: 'Contains prohibited keyword',
  })
  .superRefine((data, ctx) => {
    if (!data.hasReceipt && !data.noReceiptReason) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['noReceiptReason'],
        message: 'Reason is required when receipt is missing',
      });
    }

    if (data.startDate && data.endDate && data.endDate < data.startDate) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['endDate'],
        message: 'End date must be on or after start date',
      });
    }
  });

export type ActivityFormInput = z.infer<typeof activitySchema>;

export type ActivitySubmitPayload = {
  fiscal_year: number;
  receipt_number?: string;
  category_id: number;
  start_date: string;
  end_date: string;
  destination?: string;
  location?: string;
  activity_details: string;
  expenses: {
    expense_type: 'transportation' | 'accommodation' | 'per_diem' | 'others';
    route?: string;
    transport_method?: string;
    calculation_basis?: string;
    amount: number;
  }[];
  receipt: {
    payment_date: string;
    payee: string;
    title: string;
    total_amount: number;
    apportion_ratio: number;
    reported_amount: number;
    has_receipt: boolean;
    receipt_image_path?: string;
    no_receipt_reason?: string;
  };
  postages: {
    item_type: 'stamp' | 'postcard';
    transaction_type: 'purchase' | 'use';
    transaction_date: string;
    purpose?: string;
    quantity: number;
    price: number;
  }[];
  equipments: {
    equipment_name: string;
    quantity: number;
    acquisition_date: string;
    acquisition_price: number;
  }[];
};

type ActivityFormProps = {
  onSubmitActivity: (payload: ActivitySubmitPayload) => Promise<void>;
};

const defaultExpense = {
  expenseType: 'transportation' as const,
  route: '',
  transportMethod: '',
  calculationBasis: '',
  amount: 0,
};

export default function ActivityForm({ onSubmitActivity }: ActivityFormProps) {
  const [receiptFile, setReceiptFile] = useState<File | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const supabase = useMemo(() => {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

    if (!url || !key) {
      return null;
    }

    return createClient(url, key);
  }, []);

  const {
    register,
    control,
    watch,
    setValue,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<ActivityFormInput>({
    resolver: zodResolver(activitySchema),
    defaultValues: {
      fiscalYear: new Date().getFullYear(),
      receiptNumber: '',
      categoryId: 1,
      startDate: '',
      endDate: '',
      destination: '',
      location: '',
      activityDetails: '',
      expenses: [defaultExpense],
      paymentDate: '',
      payee: '',
      title: '',
      apportionRatioPercent: 100,
      hasReceipt: true,
      receiptImagePath: '',
      noReceiptReason: '',
      postages: [],
      equipments: [],
    },
  });

  const {
    fields: expenseFields,
    append: appendExpense,
    remove: removeExpense,
  } = useFieldArray({ control, name: 'expenses' });

  const {
    fields: postageFields,
    append: appendPostage,
    remove: removePostage,
  } = useFieldArray({ control, name: 'postages' });

  const {
    fields: equipmentFields,
    append: appendEquipment,
    remove: removeEquipment,
  } = useFieldArray({ control, name: 'equipments' });

  const watchedCategoryId = watch('categoryId');
  const watchedHasReceipt = watch('hasReceipt');
  const watchedExpenses = watch('expenses');
  const watchedApportionRatioPercent = watch('apportionRatioPercent');

  const totalAmount = watchedExpenses?.reduce((sum, item) => sum + Number(item.amount || 0), 0) ?? 0;
  const apportionRatio = Number(watchedApportionRatioPercent || 0) / 100;
  const reportedAmount = Number((totalAmount * apportionRatio).toFixed(2));

  const showPostagePanel = watchedCategoryId === 3 || watchedCategoryId === 4;
  const showEquipmentPanel = (watchedCategoryId === 7 || watchedCategoryId === 8) && totalAmount >= 10000;

  const uploadReceiptImage = async (file: File) => {
    if (!supabase) {
      throw new Error('Supabase client is not configured. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY.');
    }

    setIsUploading(true);

    try {
      const {
        data: { user },
        error: userError,
      } = await supabase.auth.getUser();

      if (userError) {
        throw userError;
      }

      if (!user) {
        throw new Error('User is not authenticated.');
      }

      const extension = file.name.split('.').pop() || 'jpg';
      const filePath = `${user.id}/${Date.now()}-${crypto.randomUUID()}.${extension}`;

      const { error: uploadError } = await supabase.storage.from('receipts').upload(filePath, file, {
        contentType: file.type,
        upsert: false,
      });

      if (uploadError) {
        throw uploadError;
      }

      setValue('receiptImagePath', filePath, { shouldValidate: true, shouldDirty: true });
      return filePath;
    } finally {
      setIsUploading(false);
    }
  };

  const submitForm = handleSubmit(async (values) => {
    setSubmitError(null);

    try {
      let receiptImagePath = values.receiptImagePath;

      if (values.hasReceipt) {
        if (!receiptImagePath && receiptFile) {
          receiptImagePath = await uploadReceiptImage(receiptFile);
        }

        if (!receiptImagePath) {
          throw new Error('Receipt file upload is required when hasReceipt is true.');
        }
      }

      const payload: ActivitySubmitPayload = {
        fiscal_year: values.fiscalYear,
        receipt_number: values.receiptNumber || undefined,
        category_id: values.categoryId,
        start_date: values.startDate,
        end_date: values.endDate,
        destination: values.destination || undefined,
        location: values.location || undefined,
        activity_details: values.activityDetails,
        expenses: values.expenses.map((expense) => ({
          expense_type: expense.expenseType,
          route: expense.route || undefined,
          transport_method: expense.transportMethod || undefined,
          calculation_basis: expense.calculationBasis || undefined,
          amount: Number(expense.amount),
        })),
        receipt: {
          payment_date: values.paymentDate,
          payee: values.payee,
          title: values.title,
          total_amount: Number(totalAmount.toFixed(2)),
          apportion_ratio: Number(apportionRatio.toFixed(4)),
          reported_amount: reportedAmount,
          has_receipt: values.hasReceipt,
          receipt_image_path: values.hasReceipt ? receiptImagePath : undefined,
          no_receipt_reason: values.hasReceipt ? undefined : values.noReceiptReason || undefined,
        },
        postages: showPostagePanel
          ? (values.postages ?? []).map((postage) => ({
              item_type: postage.itemType,
              transaction_type: postage.transactionType,
              transaction_date: postage.transactionDate,
              purpose: postage.purpose || undefined,
              quantity: Number(postage.quantity),
              price: Number(postage.price),
            }))
          : [],
        equipments: showEquipmentPanel
          ? (values.equipments ?? []).map((equipment) => ({
              equipment_name: equipment.equipmentName,
              quantity: Number(equipment.quantity),
              acquisition_date: equipment.acquisitionDate,
              acquisition_price: Number(equipment.acquisitionPrice),
            }))
          : [],
      };

      await onSubmitActivity(payload);
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : 'Failed to submit activity.');
    }
  });

  return (
    <form onSubmit={submitForm} className="mx-auto max-w-5xl space-y-8 rounded-xl border border-slate-200 bg-white p-6">
      <section className="space-y-4">
        <h2 className="text-lg font-semibold">1. Activity Basics</h2>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <label className="space-y-1">
            <span>Fiscal Year</span>
            <input type="number" className="w-full rounded border p-2" {...register('fiscalYear')} />
          </label>

          <label className="space-y-1">
            <span>Receipt Number</span>
            <input className="w-full rounded border p-2" {...register('receiptNumber')} />
          </label>

          <label className="space-y-1">
            <span>Category</span>
            <select className="w-full rounded border p-2" {...register('categoryId', { valueAsNumber: true })}>
              {CATEGORY_OPTIONS.map((option) => (
                <option key={option.id} value={option.id}>
                  {option.label}
                </option>
              ))}
            </select>
          </label>

          <label className="space-y-1">
            <span>Start Date</span>
            <input type="date" className="w-full rounded border p-2" {...register('startDate')} />
            {errors.startDate && <p className="text-sm text-red-600">{errors.startDate.message}</p>}
          </label>

          <label className="space-y-1">
            <span>End Date</span>
            <input type="date" className="w-full rounded border p-2" {...register('endDate')} />
            {errors.endDate && <p className="text-sm text-red-600">{errors.endDate.message}</p>}
          </label>

          <label className="space-y-1 md:col-span-2">
            <span>Destination</span>
            <input className="w-full rounded border p-2" {...register('destination')} />
          </label>

          <label className="space-y-1 md:col-span-2">
            <span>Location</span>
            <input className="w-full rounded border p-2" {...register('location')} />
          </label>

          <label className="space-y-1 md:col-span-2">
            <span>Activity Details</span>
            <textarea className="w-full rounded border p-2" rows={4} {...register('activityDetails')} />
            {errors.activityDetails && <p className="text-sm text-red-600">{errors.activityDetails.message}</p>}
          </label>
        </div>
      </section>

      <section className="space-y-4">
        <h2 className="text-lg font-semibold">2. Expense Details</h2>
        <div className="space-y-4">
          {expenseFields.map((field, index) => (
            <div key={field.id} className="grid grid-cols-1 gap-3 rounded border p-3 md:grid-cols-5">
              <label className="space-y-1">
                <span>Type</span>
                <select className="w-full rounded border p-2" {...register(`expenses.${index}.expenseType`)}>
                  <option value="transportation">Transportation</option>
                  <option value="accommodation">Accommodation</option>
                  <option value="per_diem">Per Diem</option>
                  <option value="others">Others</option>
                </select>
              </label>

              <label className="space-y-1">
                <span>Route</span>
                <input className="w-full rounded border p-2" {...register(`expenses.${index}.route`)} />
              </label>

              <label className="space-y-1">
                <span>Transport Method</span>
                <input className="w-full rounded border p-2" {...register(`expenses.${index}.transportMethod`)} />
              </label>

              <label className="space-y-1">
                <span>Calculation Basis</span>
                <input className="w-full rounded border p-2" {...register(`expenses.${index}.calculationBasis`)} />
              </label>

              <label className="space-y-1">
                <span>Amount</span>
                <input type="number" className="w-full rounded border p-2" {...register(`expenses.${index}.amount`, { valueAsNumber: true })} />
              </label>

              <div className="md:col-span-5">
                <button
                  type="button"
                  onClick={() => removeExpense(index)}
                  className="rounded border border-red-300 px-3 py-1 text-sm text-red-700"
                  disabled={expenseFields.length <= 1}
                >
                  Remove Expense
                </button>
              </div>
            </div>
          ))}

          <button
            type="button"
            onClick={() => appendExpense(defaultExpense)}
            className="rounded bg-slate-900 px-3 py-2 text-white"
          >
            + Add Expense
          </button>

          <p className="text-sm font-semibold">Total Amount: {totalAmount.toLocaleString()}</p>
        </div>
      </section>

      <section className="space-y-4">
        <h2 className="text-lg font-semibold">3. Evidence and Apportionment</h2>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <label className="space-y-1">
            <span>Payment Date</span>
            <input type="date" className="w-full rounded border p-2" {...register('paymentDate')} />
            {errors.paymentDate && <p className="text-sm text-red-600">{errors.paymentDate.message}</p>}
          </label>

          <label className="space-y-1">
            <span>Payee</span>
            <input className="w-full rounded border p-2" {...register('payee')} />
            {errors.payee && <p className="text-sm text-red-600">{errors.payee.message}</p>}
          </label>

          <label className="space-y-1 md:col-span-2">
            <span>Title</span>
            <input className="w-full rounded border p-2" {...register('title')} />
            {errors.title && <p className="text-sm text-red-600">{errors.title.message}</p>}
          </label>

          <label className="space-y-1">
            <span>Apportion Ratio (%)</span>
            <input
              type="number"
              step="0.01"
              className="w-full rounded border p-2"
              {...register('apportionRatioPercent', { valueAsNumber: true })}
            />
          </label>

          <div className="rounded border border-slate-200 bg-slate-50 p-3">
            <p className="text-sm">Reported Amount (auto)</p>
            <p className="text-base font-semibold">{reportedAmount.toLocaleString()}</p>
          </div>

          <fieldset className="space-y-2 md:col-span-2">
            <legend className="font-medium">Has Receipt</legend>
            <label className="mr-4 inline-flex items-center gap-2">
              <input
                type="radio"
                checked={watchedHasReceipt === true}
                onChange={() => setValue('hasReceipt', true, { shouldValidate: true })}
              />
              <span>Yes</span>
            </label>
            <label className="inline-flex items-center gap-2">
              <input
                type="radio"
                checked={watchedHasReceipt === false}
                onChange={() => setValue('hasReceipt', false, { shouldValidate: true })}
              />
              <span>No</span>
            </label>
          </fieldset>

          {watchedHasReceipt ? (
            <div className="md:col-span-2 space-y-2">
              <label className="space-y-1 block">
                <span>Receipt Image (upload to receipts bucket)</span>
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => {
                    const file = e.target.files?.[0] ?? null;
                    setReceiptFile(file);
                    if (!file) {
                      setValue('receiptImagePath', '');
                    }
                  }}
                />
              </label>
              <input type="hidden" {...register('receiptImagePath')} />
              {watch('receiptImagePath') ? (
                <p className="text-sm text-green-700">Uploaded path: {watch('receiptImagePath')}</p>
              ) : (
                <p className="text-sm text-slate-600">File will be uploaded on submit.</p>
              )}
            </div>
          ) : (
            <label className="space-y-1 md:col-span-2">
              <span>Reason (receipt not available)</span>
              <textarea className="w-full rounded border p-2" rows={3} {...register('noReceiptReason')} />
              {errors.noReceiptReason && <p className="text-sm text-red-600">{errors.noReceiptReason.message}</p>}
            </label>
          )}
        </div>
      </section>

      <section className="space-y-4">
        <h2 className="text-lg font-semibold">4. Conditional Inputs</h2>

        {showPostagePanel && (
          <div className="space-y-3 rounded border p-4">
            <h3 className="font-semibold">Postages Panel (for Public Relations / Public Hearing)</h3>
            {postageFields.map((field, index) => (
              <div key={field.id} className="grid grid-cols-1 gap-3 rounded border p-3 md:grid-cols-6">
                <label className="space-y-1">
                  <span>Item Type</span>
                  <select className="w-full rounded border p-2" {...register(`postages.${index}.itemType`)}>
                    <option value="stamp">Stamp</option>
                    <option value="postcard">Postcard</option>
                  </select>
                </label>

                <label className="space-y-1">
                  <span>Transaction</span>
                  <select className="w-full rounded border p-2" {...register(`postages.${index}.transactionType`)}>
                    <option value="purchase">Purchase</option>
                    <option value="use">Use</option>
                  </select>
                </label>

                <label className="space-y-1">
                  <span>Date</span>
                  <input type="date" className="w-full rounded border p-2" {...register(`postages.${index}.transactionDate`)} />
                </label>

                <label className="space-y-1">
                  <span>Purpose</span>
                  <input className="w-full rounded border p-2" {...register(`postages.${index}.purpose`)} />
                </label>

                <label className="space-y-1">
                  <span>Quantity</span>
                  <input type="number" className="w-full rounded border p-2" {...register(`postages.${index}.quantity`, { valueAsNumber: true })} />
                </label>

                <label className="space-y-1">
                  <span>Price</span>
                  <input type="number" className="w-full rounded border p-2" {...register(`postages.${index}.price`, { valueAsNumber: true })} />
                </label>

                <div className="md:col-span-6">
                  <button type="button" onClick={() => removePostage(index)} className="rounded border px-3 py-1 text-sm">
                    Remove Postage
                  </button>
                </div>
              </div>
            ))}

            <button
              type="button"
              onClick={() =>
                appendPostage({
                  itemType: 'stamp',
                  transactionType: 'purchase',
                  transactionDate: '',
                  purpose: '',
                  quantity: 1,
                  price: 0,
                })
              }
              className="rounded bg-slate-900 px-3 py-2 text-white"
            >
              + Add Postage
            </button>
          </div>
        )}

        {showEquipmentPanel && (
          <div className="space-y-3 rounded border p-4">
            <h3 className="font-semibold">Equipment Panel (>= 10,000 for Material categories)</h3>
            {equipmentFields.map((field, index) => (
              <div key={field.id} className="grid grid-cols-1 gap-3 rounded border p-3 md:grid-cols-4">
                <label className="space-y-1">
                  <span>Name</span>
                  <input className="w-full rounded border p-2" {...register(`equipments.${index}.equipmentName`)} />
                </label>

                <label className="space-y-1">
                  <span>Quantity</span>
                  <input type="number" className="w-full rounded border p-2" {...register(`equipments.${index}.quantity`, { valueAsNumber: true })} />
                </label>

                <label className="space-y-1">
                  <span>Acquisition Date</span>
                  <input type="date" className="w-full rounded border p-2" {...register(`equipments.${index}.acquisitionDate`)} />
                </label>

                <label className="space-y-1">
                  <span>Acquisition Price</span>
                  <input
                    type="number"
                    className="w-full rounded border p-2"
                    {...register(`equipments.${index}.acquisitionPrice`, { valueAsNumber: true })}
                  />
                </label>

                <div className="md:col-span-4">
                  <button type="button" onClick={() => removeEquipment(index)} className="rounded border px-3 py-1 text-sm">
                    Remove Equipment
                  </button>
                </div>
              </div>
            ))}

            <button
              type="button"
              onClick={() =>
                appendEquipment({
                  equipmentName: '',
                  quantity: 1,
                  acquisitionDate: '',
                  acquisitionPrice: 0,
                })
              }
              className="rounded bg-slate-900 px-3 py-2 text-white"
            >
              + Add Equipment
            </button>
          </div>
        )}
      </section>

      {submitError && <p className="text-sm text-red-700">{submitError}</p>}

      <div className="flex items-center gap-3">
        <button
          type="submit"
          disabled={isSubmitting || isUploading}
          className="rounded bg-blue-700 px-4 py-2 font-medium text-white disabled:opacity-60"
        >
          {isSubmitting || isUploading ? 'Submitting...' : 'Submit Activity'}
        </button>
      </div>
    </form>
  );
}
