export function validate(required = []) {
  return (req, res, next) => {
    const body = req.body || {};
    const miss = required.filter(k => !(k in body));
    if (miss.length) return res.status(422).json({ error: 'Unprocessable Entity', missing: miss });
    next();
  };
}
