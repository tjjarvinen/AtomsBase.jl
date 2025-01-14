using AtomsBaseTesting
using Test
using LinearAlgebra
using AtomsBase
using Unitful
using UnitfulAtomic

include("testmacros.jl")

@testset "AtomsBaseTesting.jl" begin
    @testset "make_test_system" begin
        let case = make_test_system()
            # Data that is delivered agrees with the constructed system
            # TODO Could test more here
            @test sort(collect(keys(case.atprop)))  == sort(collect(atomkeys(case.system)))
            @test sort(collect(keys(case.atprop)))  == sort(collect(keys(case.atoms[1])))
            @test sort(collect(keys(case.sysprop))) == sort(collect(keys(case.system)))
            @test case.bounding_box  == bounding_box(case.system)
            @test case.periodicity   == periodicity(case.system)
        end

        let case = make_test_system(; cellmatrix=:full)
            box = reduce(hcat, bounding_box(case.system))
            @test UpperTriangular(box) != box
            @test LowerTriangular(box) != box
            @test Diagonal(box) != box
        end
        let case = make_test_system(; cellmatrix=:upper_triangular)
            box = reduce(hcat, bounding_box(case.system))
            @test UpperTriangular(box) == box
            @test LowerTriangular(box) != box
            @test Diagonal(box) != box
        end
        let case = make_test_system(; cellmatrix=:lower_triangular)
            box = reduce(hcat, bounding_box(case.system))
            @test UpperTriangular(box) != box
            @test LowerTriangular(box) == box
            @test Diagonal(box) != box
        end
        let case = make_test_system(; cellmatrix=:diagonal)
            box = reduce(hcat, bounding_box(case.system))
            @test Diagonal(box) == box
            @test UpperTriangular(box) == box
            @test LowerTriangular(box) == box
        end

        @test  hasatomkey(make_test_system().system,                            :vdw_radius)
        @test !hasatomkey(make_test_system(; drop_atprop=[:vdw_radius]).system, :vdw_radius)

        @test  haskey(make_test_system().system,                               :multiplicity)
        @test !haskey(make_test_system(; drop_sysprop=[:multiplicity]).system, :multiplicity)
    end

    @testset "Identical systems should pass" begin
        case = make_test_system()
        test_approx_eq(case.system, case.system)
    end

    @testset "Cell distortion" begin
        # TODO This can be simplified to
        #      (; system, atoms, box, bcs, sysprop) = make_test_system()
        # once we require Julia 1.7
        case = make_test_system()
        system = case.system
        atoms  = case.atoms
        box    = case.bounding_box
        bcs    = case.periodicity
        sysprop = case.sysprop
        # end simplify

        box_dist = tuple([v .+ 1e-5u"Å" * ones(3) for v in box]...)
        system_dist = atomic_system(atoms, box_dist, bcs; sysprop...)

        @testfail test_approx_eq(system, system_dist; rtol=1e-12)
        @testpass test_approx_eq(system, system_dist; rtol=1e-3)
    end

    @testset "ignore_sysprop / common_only" begin
        # TODO This can be simplified to
        #      (; system, atoms, box, bcs, sysprop) = make_test_system()
        # once we require Julia 1.7
        case = make_test_system()
        system = case.system
        atoms  = case.atoms
        box    = case.bounding_box
        bcs    = case.periodicity
        sysprop = case.sysprop
        # end simplify

        sysprop_dict = Dict(pairs(sysprop))
        pop!(sysprop_dict, :multiplicity)
        system_edit = atomic_system(atoms, box, bcs; sysprop_dict...)

        @testfail test_approx_eq(system, system_edit, quiet=true)
        @testpass test_approx_eq(system, system_edit; ignore_sysprop=[:multiplicity])
        @testpass test_approx_eq(system, system_edit; common_only=true)
    end

    @testset "Identical systems without multiplicity" begin
        case = make_test_system(; drop_sysprop=[:multiplicity])
        @testpass test_approx_eq(case.system, case.system)
    end

    @testset "test_approx_eq for isolated molecules" begin
        hydrogen = isolated_system([
            :H => [0, 0, 0.]u"Å",
            :H => [0, 0, 1.]u"Å",
        ])
        test_approx_eq(hydrogen, hydrogen)
    end

    @testset "Identical systems with just different units" begin
        box = 10.26 / 2 * [[0, 0, 1], [1, 0, 1], [1, 1, 0]]u"bohr"
        box_A = [[uconvert.(u"Å", i[j]) for j in 1:3] for i in box]
        silicon = AtomsBase.periodic_system([:Si =>  ones(3)/8,
                                   :Si => -ones(3)/8],
                                   box, fractional=true)
        silicon_A = AtomsBase.periodic_system([:Si =>  ones(3)/8,
                                   :Si => -ones(3)/8],
                                   box_A, fractional=true)
        @testpass AtomsBaseTesting.test_approx_eq(silicon, silicon_A)
    end

    # TODO More tests would be useful
end
