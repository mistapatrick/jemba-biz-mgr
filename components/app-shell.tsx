import { Sidebar } from './sidebar';
import { logout } from '@/app/login/actions';
export function AppShell({children,role,name}:{children:React.ReactNode;role:string;name:string}){return <div className="shell"><Sidebar role={role}/><div className="main"><header className="topbar"><strong>Jemba Business Manager</strong><div style={{display:'flex',alignItems:'center',gap:14,fontSize:13}}><span>{name}</span><form action={logout}><button className="btn light" style={{padding:'8px 11px'}}>Sign out</button></form></div></header><main className="content">{children}</main></div></div>}
