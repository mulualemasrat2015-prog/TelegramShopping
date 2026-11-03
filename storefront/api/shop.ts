import type { VercelRequest, VercelResponse } from '@vercel/node'
import { createClient } from '@supabase/supabase-js'
import { createHmac, timingSafeEqual } from 'node:crypto'

const db = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_KEY!)
const one = (v: any) => (Array.isArray(v) ? v[0] ?? null : v)

// Checks that initData was really signed by Telegram for THIS shop's bot.
function verify(initData: string, botToken: string) {
  const p = new URLSearchParams(initData)
  const hash = p.get('hash')
  if (!hash) return null
  p.delete('hash')
  const check = [...p.entries()].map(([k, v]) => `${k}=${v}`).sort().join('\n')
  const secret = createHmac('sha256', 'WebAppData').update(botToken).digest()
  const calc = createHmac('sha256', secret).update(check).digest('hex')
  const a = Buffer.from(calc, 'hex')
  const b = Buffer.from(hash, 'hex')
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null
  if (Date.now() / 1000 - Number(p.get('auth_date')) > 86400) return null
  return JSON.parse(p.get('user') ?? 'null')
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  res.setHeader('Cache-Control', 'no-store')
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' })
  const { shop: slug, initData } = req.body ?? {}
  if (typeof slug !== 'string' || typeof initData !== 'string') {
    return res.status(400).json({ error: 'Missing shop or initData' })
  }

  const { data } = await db
    .from('shops')
    .select('id,name,description,logo_url,status,currency,verified,shop_bots(token),shop_themes(primary_color)')
    .eq('slug', slug)
    .maybeSingle()
  const row: any = data
  const token = one(row?.shop_bots)?.token
  if (!row || !token) return res.status(404).json({ error: 'Shop not found' })

  const user = verify(initData, token)
  if (!user) return res.status(401).json({ error: 'Telegram data could not be verified' })

  const shop = {
    name: row.name, description: row.description, logo_url: row.logo_url,
    currency: row.currency, verified: row.verified, status: row.status,
  }
  const theme = one(row.shop_themes)
  if (row.status === 'paused' || row.status === 'suspended') {
    return res.json({ shop, theme, products: [], closed: true })
  }

  const { data: u } = await db
    .from('users')
    .upsert(
      { telegram_id: user.id, first_name: user.first_name, username: user.username ?? null, language: user.language_code ?? null },
      { onConflict: 'telegram_id' },
    )
    .select('id')
    .single()
  if (u) await db.from('customers').upsert({ shop_id: row.id, user_id: u.id }, { onConflict: 'shop_id,user_id' })

  const { data: products } = await db
    .from('products')
    .select('id,title,description,price,compare_at_price,status,stock_qty,product_media(url,sort_order)')
    .eq('shop_id', row.id)
    .in('status', ['active', 'sold_out'])
    .order('created_at', { ascending: false })

  return res.json({ shop, theme, products: products ?? [], closed: false })
}
