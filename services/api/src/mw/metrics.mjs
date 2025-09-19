const samples = [];
const MAX = 500;

function percentile(arr, p) {
  if (!arr.length) return 0;
  const a = [...arr].sort((x,y)=>x-y);
  const i = Math.ceil((p/100)*a.length) - 1;
  return a[Math.max(0, i)];
}

export const metrics = () => (req, res, next) => {
  const t0 = Date.now();
  res.on("finish", () => {
    const dt = Date.now() - t0;
    samples.push(dt);
    if (samples.length > MAX) samples.shift();
  });
  next();
};

export const mountMetricsRoute = (app, base="/api") => {
  app.get(`${base}/metrics`, (_req, res) => {
    res.json({
      count: samples.length,
      p50: percentile(samples, 50),
      p95: percentile(samples, 95),
      p99: percentile(samples, 99),
    });
  });
};
