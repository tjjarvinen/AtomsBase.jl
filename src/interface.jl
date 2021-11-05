using Unitful
using UnitfulAtomic
using PeriodicTable
using StaticArrays
import Base.position

export AbstractElement, AbstractParticle, AbstractAtom, AbstractSystem, AbstractAtomicSystem
export ChemicalElement, SimpleAtom
export BoundaryCondition, DirichletZero, Periodic
export atomic_mass,
    atomic_number,
    atomic_symbol,
    bounding_box,
    element,
    position,
    velocity,
    boundary_conditions,
    periodic_dims
export atomic_property, has_atomic_property, atomic_propertynames
export n_dimensions


abstract type AbstractElement end
struct ChemicalElement <: AbstractElement
    data::PeriodicTable.Element
end

ChemicalElement(symbol::Union{Symbol,Integer,AbstractString}) =
    ChemicalElement(PeriodicTable.elements[symbol])
Base.show(io::IO, elem::ChemicalElement) = print(io, "Element(", atomic_symbol(elem), ")")

# These are always only read-only ... and allow look-up into a database
atomic_symbol(el::ChemicalElement) = el.data.symbol
atomic_number(el::ChemicalElement) = el.data.number
atomic_mass(el::ChemicalElement) = el.data.atomic_mass



#
# A distinguishable particle, can be anything associated with coordinate
# information (position, velocity, etc.)
# most importantly: Can have any identifier type
#
# IdType:  Type used to identify the particle
#
abstract type AbstractParticle{ET<:AbstractElement} end
velocity(::AbstractParticle)::AbstractVector{<:Unitful.Velocity} = missing
position(::AbstractParticle)::AbstractVector{<:Unitful.Length} = error("Implement me")
(element(::AbstractParticle{ET})::ET) where {ET<:AbstractElement} = error("Implement me")


#
# The atom type itself
#     - The atom interface is read-only (to allow as simple as possible implementation)
#       Writability may be supported in derived or concrete types.
#     - The inferface is only in Cartesian coordinates.
#     - Has atom-specific defaults (i.e. assumes every entity represents an atom or ion)
#

const AbstractAtom = AbstractParticle{ChemicalElement}
element(::AbstractAtom)::ChemicalElement = error("Implement me")


# Extracting things ... it might make sense to make some of them writable in concrete
# implementations, therefore these interfaces are forwarded from the Element object.
atomic_symbol(atom::AbstractAtom) = atomic_symbol(element(atom))
atomic_number(atom::AbstractAtom) = atomic_number(element(atom))
atomic_mass(atom::AbstractAtom) = atomic_mass(element(atom))

# Custom atomic properties:
atomic_property(::AbstractAtom, ::Symbol, default = missing) = default
has_atomic_property(atom::AbstractAtom, property::Symbol) =
    !ismissing(atomic_property(atom, property))
atomic_propertynames(::AbstractAtom) = Symbol[]

#
# Identifier for boundary conditions per dimension
#
abstract type BoundaryCondition end
struct DirichletZero <: BoundaryCondition end  # Dirichlet zero boundary (i.e. molecular context)
struct Periodic <: BoundaryCondition end  # Periodic BCs


#
# The system type
#     Again readonly.
#

abstract type AbstractSystem{D,ET<:AbstractElement,AT<:AbstractParticle{ET}} end
(bounding_box(::AbstractSystem{D})::SVector{D,SVector{D,<:Unitful.Length}}) where {D} =
    error("Implement me")
(boundary_conditions(::AbstractSystem{D})::SVector{D,BoundaryCondition}) where {D} =
    error("Implement me")

get_periodic(sys::AbstractSystem) =
    [isa(bc, Periodic) for bc in get_boundary_conditions(sys)]

# Note: Can't use ndims, because that is ndims(sys) == 1 (because of AbstractVector interface)
n_dimensions(::AbstractSystem{D}) where {D} = D


# indexing interface
Base.getindex(::AbstractSystem, ::Int) = error("Implement me")
Base.size(::AbstractSystem) = error("Implement me")
Base.length(::AbstractSystem) = error("Implement me")
Base.setindex!(::AbstractSystem, ::Int) = error("AbstractSystem objects are not mutable.")
Base.firstindex(::AbstractSystem) = 1
Base.lastindex(s::AbstractSystem) = length(s)

# iteration interface, needed for default broadcast dispatches below to work
Base.iterate(sys::AbstractSystem{D,ET,AT}, state = firstindex(sys)) where {D,ET,AT} =
    state > length(sys) ? nothing : (sys[state], state + 1)

# TODO Support similar, push, ...

# Some implementations might prefer to store data in the System as a flat list and
# expose Atoms as a view. Therefore these functions are needed. Of course this code
# should be autogenerated later on ...
position(sys::AbstractSystem) = position.(sys)    # in Cartesian coordinates!
velocity(sys::AbstractSystem) = velocity.(sys)    # in Cartesian coordinates!
element(sys::AbstractSystem) = element.(sys)

#
# Extra stuff only for Systems composed of atoms
#
const AbstractAtomicSystem{D,AT<:AbstractAtom} = AbstractSystem{D,ChemicalElement,AT}
atomic_symbol(sys::AbstractAtomicSystem) = atomic_symbol.(sys)
atomic_number(sys::AbstractAtomicSystem) = atomic_number.(sys)
atomic_mass(sys::AbstractAtomicSystem) = atomic_mass.(sys)
atomic_property(sys::AbstractAtomicSystem, property::Symbol)::Vector{Any} =
    atomic_property.(sys, property)
atomic_propertiesnames(sys::AbstractAtomicSystem) = unique(sort(atomic_propertynames.(sys)))

struct SimpleAtom{D} <: AbstractAtom
    position::SVector{D,<:Unitful.Length}
    element::ChemicalElement
end
SimpleAtom(position, element) = SimpleAtom{length(position)}(position, element)
position(atom::SimpleAtom) = atom.position
element(atom::SimpleAtom) = atom.element

function SimpleAtom(position, symbol::Union{Integer,AbstractString,Symbol,AbstractVector})
    SimpleAtom(position, ChemicalElement(symbol))
end

# Just to make testing a little easier for now
function Base.show(io::IO, ::MIME"text/plain", part::AbstractParticle)
    print(io, "Particle(", element(part), ") @ ", position(part))
end
function Base.show(io::IO, ::MIME"text/plain", part::AbstractAtom)
    print(io, "Atom(", atomic_symbol(part), ") @ ", position(part))
end
function Base.show(io::IO, mime::MIME"text/plain", sys::AbstractSystem)
    println(io, "System:")
    println(io, "    BCs:        ", boundary_conditions(sys))
    println(io, "    Box:        ", bounding_box(sys))
    println(io, "    Particles:  ")
    for particle in sys
        Base.show(io, mime, particle)
        println(io)
    end
end
