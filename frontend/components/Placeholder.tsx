// Stub screen for the shell. Each route gets a home to grow into.
export default function Placeholder({ title }: { title: string }) {
  return (
    <section>
      <h1 className="page-heading text-green mb-4">{title}</h1>
      <p className="text-muted">Coming soon.</p>
    </section>
  )
}
