'use server';
import { revalidatePath } from 'next/cache';
import { requireRole } from '@/lib/auth';
export async function createCustomer(formData:FormData){const {supabase,profile}=await requireRole(['owner_admin','customer_relationship_officer','super_admin']);const name=String(formData.get('name')||'').trim();if(!name)throw new Error('Customer name is required');const {error}=await supabase.from('customers').insert({business_id:profile.business_id,name,email:String(formData.get('email')||'').trim()||null,phone:String(formData.get('phone')||'').trim()||null,address:String(formData.get('address')||'').trim()||null});if(error)throw new Error(error.message);revalidatePath('/customers');}
