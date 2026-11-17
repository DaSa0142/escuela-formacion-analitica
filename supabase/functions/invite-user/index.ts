// Deploy with: supabase functions deploy invite-user --no-verify-jwt
// Authorization is enforced within handler with auth.getUser() and DB is_admin().
import { createClient } from 'npm:@supabase/supabase-js@2';
const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
Deno.serve(async (req) => {
  if (req.method==='OPTIONS') return new Response('ok',{headers:cors});
  if (req.method!=='POST') return new Response('Método no permitido',{status:405,headers:cors});
  try {
    const url=Deno.env.get('SUPABASE_URL')!;
    const publicKey=Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY')!;
    const secretKey=Deno.env.get('SUPABASE_SECRET_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const bearer=req.headers.get('authorization')?.replace(/^Bearer\s+/i,'');
    if (!bearer) return Response.json({error:'Inicia sesión'},{status:401,headers:cors});
    const publicClient=createClient(url,publicKey,{global:{headers:{Authorization:`Bearer ${bearer}`}},auth:{persistSession:false}});
    const {data:{user},error:authError}=await publicClient.auth.getUser(bearer);
    if(authError||!user) return Response.json({error:'Sesión inválida'},{status:401,headers:cors});
    const {data:admin,error:roleError}=await publicClient.rpc('is_admin');
    if(roleError||!admin) return Response.json({error:'No autorizado'},{status:403,headers:cors});
    const body=await req.json();
    const email=String(body.email||'').trim().toLowerCase();
    const name=String(body.name||'').trim();
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||name.length<3||name.length>160) return Response.json({error:'Correo o nombre no válido'},{status:400,headers:cors});
    const adminClient=createClient(url,secretKey,{auth:{persistSession:false,autoRefreshToken:false}});
    const {error}=await adminClient.auth.admin.inviteUserByEmail(email,{data:{name},redirectTo:String(body.redirectTo||'')});
    if(error) throw error;
    return Response.json({ok:true,message:'Invitación enviada'},{headers:cors});
  }catch(e){return Response.json({error:String(e.message||e)},{status:400,headers:cors});}
});
