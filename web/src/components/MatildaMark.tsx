export function MatildaMark({ className = "h-3 w-5" }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 12" className={className} aria-hidden fill="none">
      <path d="M2 3 Q10 15 18 3" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" />
    </svg>
  );
}
