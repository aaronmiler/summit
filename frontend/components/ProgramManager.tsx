import { useState } from 'react'
import { usePrograms, useCreateProgram, useUpdateProgram, useDeleteProgram } from '~/api/queries'
import type { Program } from '~/types'

// Lightweight program management on the Library landing: add, rename (inline,
// saves on blur/Enter), delete. Deleting only ungroups its routines (FK nullify),
// so it's low-stakes — the routines and their history are untouched.
export default function ProgramManager() {
  const { data: programs } = usePrograms()
  const create = useCreateProgram()
  const [newName, setNewName] = useState('')

  function add() {
    const name = newName.trim()
    if (!name) return
    create.mutate({ name, notes: null }, { onSuccess: () => setNewName('') })
  }

  return (
    <div className="program-manager">
      {programs && programs.length > 0 && (
        <ul className="program-list">
          {programs.map((program) => (
            <ProgramRow key={program.id} program={program} />
          ))}
        </ul>
      )}
      <div className="program-add">
        <input
          className="form-input"
          value={newName}
          onChange={(e) => setNewName(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && add()}
          placeholder="New program"
          aria-label="New program name"
        />
        <button
          className="btn btn--secondary btn--compact"
          type="button"
          onClick={add}
          disabled={!newName.trim() || create.isPending}
        >
          Add
        </button>
      </div>
    </div>
  )
}

function ProgramRow({ program }: { program: Program }) {
  const update = useUpdateProgram(program.id)
  const del = useDeleteProgram()
  const [name, setName] = useState(program.name)

  // Commit a rename on blur/Enter; a blank or unchanged value snaps back.
  function rename() {
    const next = name.trim()
    if (!next || next === program.name) {
      setName(program.name)
      return
    }
    update.mutate({ name: next, notes: program.notes })
  }

  return (
    <li className="program-row">
      <input
        className="form-input program-row__name"
        value={name}
        onChange={(e) => setName(e.target.value)}
        onBlur={rename}
        onKeyDown={(e) => e.key === 'Enter' && e.currentTarget.blur()}
        aria-label="Program name"
      />
      <button
        className="btn btn--ghost btn--compact"
        type="button"
        onClick={() => del.mutate(program.id)}
        title="Delete program (its routines stay, just ungrouped)"
        aria-label={`Delete ${program.name}`}
      >
        ×
      </button>
    </li>
  )
}
