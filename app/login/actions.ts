'use server';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
export async function login(formData: FormData){const email=String(formData.get('email')||'').trim();const password=String(formData.get('password')||'');if(!email||!password)redirect('/login?error=Enter%20email%20and%20password');const s=await createClient();const {error}=await s.auth.signInWithPassword({email,password});if(error)redirect('/login?error=Invalid%20email%20or%20password');redirect('/dashboard');}
export async function logout(){const s=await createClient();await s.auth.signOut();redirect('/login');}
