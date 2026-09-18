"use client";

export function Field({ label, className, children }: { label: string; className?: string; children: React.ReactNode }) {
  return (
    <div className={`flex flex-col gap-1.5 ${className ?? ""}`}>
      <label className="text-[0.76rem] font-semibold uppercase tracking-wide text-ink-soft">{label}</label>
      {children}
    </div>
  );
}

export function RemoveButton({ onClick }: { onClick: () => void }) {
  return (
    <button type="button" onClick={onClick} aria-label="retirer" className="flex h-6.5 w-6.5 shrink-0 items-center justify-center rounded-md text-ink-soft hover:bg-surface-2 hover:text-accent">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" className="h-3.5 w-3.5">
        <path d="M6 6l12 12M18 6 6 18" />
      </svg>
    </button>
  );
}

export function AddRowButton({ onClick, children }: { onClick: () => void; children: React.ReactNode }) {
  return (
    <button type="button" onClick={onClick} className="mt-2 self-start rounded-lg border border-dashed border-line px-3 py-1.5 text-[0.8rem] text-ink-soft hover:border-accent hover:text-accent">
      {children}
    </button>
  );
}
