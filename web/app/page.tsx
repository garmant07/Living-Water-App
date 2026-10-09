import SampleBadge from "@/components/SampleBadge";
import {
  formatCurrency,
  formatNumber,
  getPartners,
  getTotals,
} from "@/lib/data";

export default function Home() {
  const totals = getTotals();
  const partners = getPartners();
  const { progress } = totals;

  return (
    <main className="mx-auto flex w-full max-w-md flex-1 flex-col gap-10 px-5 py-10">
      <header className="flex flex-col items-center gap-6 text-center">
        {/* Stand-in for the interactive globe, which arrives in step 2. */}
        <div className="water-orb h-40 w-40 rounded-full" aria-hidden="true" />
        <div className="flex flex-col gap-3">
          {/* PLACEHOLDER wordmark until the real logo is supplied. */}
          <h1 className="text-4xl font-semibold tracking-tight text-brand-strong">
            Living Water Co.
          </h1>
          <p className="text-lg leading-7 text-muted">
            Every bottle helps bring clean water to a community in need. See
            where it&apos;s reaching, and how far there is still to go.
          </p>
        </div>
      </header>

      <section
        aria-labelledby="together-heading"
        className="flex flex-col gap-4 rounded-3xl border border-border bg-surface p-5"
      >
        <div className="flex items-center justify-between gap-3">
          <h2 id="together-heading" className="text-xl font-semibold">
            Together so far
          </h2>
          {totals.includesSampleData && <SampleBadge />}
        </div>

        <dl className="grid grid-cols-2 gap-4">
          <Stat label="People reached" value={formatNumber(totals.peopleServed)} />
          <Stat label="Communities" value={formatNumber(totals.communities)} />
          <Stat label="Countries" value={formatNumber(totals.countries)} />
          <Stat label="Bottles sold" value={formatNumber(totals.bottlesSold)} />
        </dl>

        <div className="flex flex-col gap-2">
          <div
            role="progressbar"
            aria-label="Raised toward all project goals"
            aria-valuemin={0}
            aria-valuemax={100}
            aria-valuenow={progress.percent}
            className="h-3 w-full overflow-hidden rounded-full bg-progress-track"
          >
            <div
              className="h-full rounded-full bg-brand"
              style={{ width: `${progress.percent}%` }}
            />
          </div>
          <p className="text-base leading-6">
            <strong>{formatCurrency(progress.raised)}</strong> raised of{" "}
            {formatCurrency(progress.goal)}.{" "}
            <strong>{formatCurrency(progress.remaining)} still to go.</strong>
          </p>
        </div>
      </section>

      <section aria-labelledby="partners-heading" className="flex flex-col gap-3">
        <h2 id="partners-heading" className="text-xl font-semibold">
          The ministries doing the work
        </h2>
        <ul className="flex flex-col gap-3">
          {partners.map((partner) => (
            <li
              key={partner.id}
              className="rounded-2xl border border-border bg-surface p-4"
            >
              <p className="text-lg font-semibold">{partner.name}</p>
              <p className="text-base text-muted">
                {partner.countries.length} countries · since {partner.founded}
              </p>
            </li>
          ))}
        </ul>
      </section>

      <figure className="flex flex-col gap-2 border-l-4 border-accent pl-4">
        <blockquote className="text-lg leading-7">
          &ldquo;Whoever drinks the water I give them will never thirst.&rdquo;
        </blockquote>
        <figcaption className="text-base text-muted">John 4:14</figcaption>
      </figure>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col-reverse">
      <dt className="text-base text-muted">{label}</dt>
      <dd className="text-3xl font-semibold text-brand-strong">{value}</dd>
    </div>
  );
}
