// A small label shown wherever invented placeholder numbers appear,
// so sample data is never mistaken for real impact.
export default function SampleBadge() {
  return (
    <span className="inline-flex items-center rounded-full bg-sample-bg px-2.5 py-1 text-xs font-semibold text-sample-fg">
      Sample data
    </span>
  );
}
