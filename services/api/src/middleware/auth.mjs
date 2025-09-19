export default function auth(req,res,next){
  const expected=process.env.AUTH_TOKEN;
  if(!expected||!expected.trim())
    return res.status(500).json({error:'server_misconfigured',message:'AUTH_TOKEN missing'});
  const header=req.headers['authorization']||'';
  const [scheme,token]=header.split(' ');
  if(!scheme||!token)
    return res.status(400).json({error:'bad_request',message:'Use: Authorization: Bearer <token>'});
  if(scheme.toLowerCase()!=='bearer')
    return res.status(400).json({error:'bad_request',message:'Authorization scheme must be Bearer'});
  if(token!==expected){
    res.set('WWW-Authenticate','Bearer realm="RSOC API"');
    return res.status(401).json({error:'unauthorized',message:'Invalid bearer token'});
  }
  next();
}
