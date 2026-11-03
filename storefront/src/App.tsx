import { useEffect, useState } from 'react'

type Product = {
  id: string; title: string; description: string | null
  price: number; compare_at_price: number | null
  status: 'active' | 'sold_out'; stock_qty: number
  product_media: { url: string; sort_order: number }[]
}
type Data = {
  shop: { name: string; description: string | null; logo_url: string | null; currency: string; verified: boolean; status: string }
  theme: { primary_color: string } | null
  products: Product[]
  closed: boolean
}

const tg = (window as any).Telegram?.WebApp
const TINTS = ['#E3EAF4', '#F4E6DD', '#E6EFE3', '#EFE6F3']
const DOTS = ['#C5D3E8', '#E8CBB8', '#C8DCC1', '#D9C6E4']
const INK = '#16161A'
const MUTED = '#66666C'

function shopSlug(): string | null {
  return new URLSearchParams(location.search).get('shop') ?? tg?.initDataUnsafe?.start_param ?? null
}

function Message({ title, text }: { title: string; text?: string }) {
  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 40, textAlign: 'center' }}>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{title}</div>
      {text && <div style={{ color: MUTED, marginTop: 8, lineHeight: 1.5 }}>{text}</div>}
    </div>
  )
}

export default function App() {
  const [data, setData] = useState<Data | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    tg?.ready()
    tg?.expand()
    const shop = shopSlug()
    if (!tg?.initData) return setError('Open this shop from Telegram.')
    if (!shop) return setError('This link has no shop in it.')
    fetch('/api/shop', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ shop, initData: tg.initData }),
    })
      .then(async (r) => {
        if (!r.ok) throw new Error((await r.json()).error ?? 'Something went wrong')
        return r.json()
      })
      .then(setData)
      .catch((e) => setError(e.message))
  }, [])

  if (error) return <Message title="Could not open the shop" text={error} />
  if (!data) return <Message title="Loading" />
  if (data.closed) return <Message title={`${data.shop.name} is closed for now`} text="Orders are paused. Please check back soon." />

  const { shop, theme, products } = data
  const accent = theme?.primary_color ?? '#1F6F54'
  const price = (n: number) => `${shop.currency} ${Number(n).toLocaleString('en-US')}`

  return (
    <div style={{ maxWidth: 480, margin: '0 auto', paddingBottom: 32 }}>
      <header style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '16px 20px' }}>
        {shop.logo_url ? (
          <img src={shop.logo_url} alt="" width={40} height={40} style={{ borderRadius: 20, objectFit: 'cover' }} />
        ) : (
          <div style={{ width: 40, height: 40, borderRadius: 20, background: accent, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700 }}>
            {shop.name.charAt(0)}
          </div>
        )}
        <div>
          <div style={{ fontWeight: 700 }}>{shop.name}</div>
          {shop.verified && <div style={{ fontSize: 12, color: accent, fontWeight: 700 }}>Verified shop</div>}
        </div>
      </header>
      {shop.description && <p style={{ margin: '0 20px 16px', color: MUTED, lineHeight: 1.5 }}>{shop.description}</p>}

      {products.length === 0 ? (
        <Message title="No products yet" text="Check back soon." />
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, padding: '0 20px' }}>
          {products.map((p, i) => {
            const img = [...p.product_media].sort((a, b) => a.sort_order - b.sort_order)[0]
            const soldOut = p.status === 'sold_out'
            return (
              <div key={p.id} style={{ opacity: soldOut ? 0.6 : 1 }}>
                <div style={{ position: 'relative', height: 130, borderRadius: 16, background: TINTS[i % 4], display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}>
                  {img ? (
                    <img src={img.url} alt={p.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  ) : (
                    <div style={{ width: 60, height: 60, borderRadius: 30, background: DOTS[i % 4] }} />
                  )}
                  {soldOut && (
                    <span style={{ position: 'absolute', left: 8, top: 8, background: '#fff', color: INK, fontSize: 12, fontWeight: 700, borderRadius: 12, padding: '4px 10px' }}>
                      Sold out
                    </span>
                  )}
                </div>
                <div style={{ fontWeight: 700, fontSize: 14, marginTop: 8 }}>{p.title}</div>
                <div style={{ color: MUTED, fontSize: 14 }}>{price(p.price)}</div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
