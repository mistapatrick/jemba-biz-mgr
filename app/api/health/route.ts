import {NextResponse} from 'next/server';
export async function GET(){const configured=!!process.env.NEXT_PUBLIC_SUPABASE_URL&&!!process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;return NextResponse.json({status:'ok',application:'Jemba Business Manager',databaseConfiguration:configured?'configured':'missing',timestamp:new Date().toISOString()},{status:configured?200:503});}
