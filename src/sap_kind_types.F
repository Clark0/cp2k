!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright (C) 2000 - 2019  CP2K developers group                                               !
!--------------------------------------------------------------------------------------------------!
! **************************************************************************************************
!> \brief General overlap type integrals containers
!> \par History
!>      - rewrite of PPNL and OCE integrals
! **************************************************************************************************
MODULE sap_kind_types

   USE kinds,                           ONLY: dp
   USE util,                            ONLY: locate,&
                                              sort
#include "./base/base_uses.f90"

   IMPLICIT NONE

   PRIVATE

   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'sap_kind_types'

   TYPE clist_type
      INTEGER                                    :: catom, nsgf_cnt
      INTEGER, DIMENSION(:), POINTER             :: sgf_list
      INTEGER, DIMENSION(3)                      :: cell
      LOGICAL                                    :: sgf_soft_only
      REAL(KIND=dp)                            :: maxac, maxach
      REAL(KIND=dp), DIMENSION(3)              :: rac
      REAL(KIND=dp), DIMENSION(:, :, :), POINTER :: acint
      REAL(KIND=dp), DIMENSION(:, :, :), POINTER :: achint
   END TYPE clist_type

   TYPE alist_type
      INTEGER                                    :: aatom
      INTEGER                                    :: nclist
      TYPE(clist_type), DIMENSION(:), POINTER    :: clist
   END TYPE alist_type

   TYPE sap_int_type
      INTEGER                                    :: a_kind, p_kind
      INTEGER                                    :: nalist
      TYPE(alist_type), DIMENSION(:), POINTER    :: alist
      INTEGER, DIMENSION(:), POINTER             :: asort, aindex
   END TYPE sap_int_type

   PUBLIC :: sap_int_type, clist_type, alist_type, &
             release_sap_int, get_alist, alist_pre_align_blk, &
             alist_post_align_blk, sap_sort

CONTAINS

!==========================================================================================================

! **************************************************************************************************
!> \brief ...
!> \param sap_int ...
! **************************************************************************************************
   SUBROUTINE release_sap_int(sap_int)

      TYPE(sap_int_type), DIMENSION(:), POINTER          :: sap_int

      CHARACTER(LEN=*), PARAMETER :: routineN = 'release_sap_int', &
         routineP = moduleN//':'//routineN

      INTEGER                                            :: i, j, k
      TYPE(clist_type), POINTER                          :: clist

      CPASSERT(ASSOCIATED(sap_int))

      DO i = 1, SIZE(sap_int)
         IF (ASSOCIATED(sap_int(i)%alist)) THEN
            DO j = 1, SIZE(sap_int(i)%alist)
               IF (ASSOCIATED(sap_int(i)%alist(j)%clist)) THEN
                  DO k = 1, SIZE(sap_int(i)%alist(j)%clist)
                     clist => sap_int(i)%alist(j)%clist(k)
                     IF (ASSOCIATED(clist%acint)) THEN
                        DEALLOCATE (clist%acint)
                     END IF
                     IF (ASSOCIATED(clist%sgf_list)) THEN
                        DEALLOCATE (clist%sgf_list)
                     END IF
                     IF (ASSOCIATED(clist%achint)) THEN
                        DEALLOCATE (clist%achint)
                     END IF
                  END DO
                  DEALLOCATE (sap_int(i)%alist(j)%clist)
               END IF
            END DO
            DEALLOCATE (sap_int(i)%alist)
         END IF
         IF (ASSOCIATED(sap_int(i)%asort)) THEN
            DEALLOCATE (sap_int(i)%asort)
         END IF
         IF (ASSOCIATED(sap_int(i)%aindex)) THEN
            DEALLOCATE (sap_int(i)%aindex)
         END IF
      END DO

      DEALLOCATE (sap_int)

   END SUBROUTINE release_sap_int

! **************************************************************************************************
!> \brief ...
!> \param sap_int ...
!> \param alist ...
!> \param atom ...
! **************************************************************************************************
   SUBROUTINE get_alist(sap_int, alist, atom)

      TYPE(sap_int_type), INTENT(IN)                     :: sap_int
      TYPE(alist_type), INTENT(OUT), POINTER             :: alist
      INTEGER, INTENT(IN)                                :: atom

      CHARACTER(LEN=*), PARAMETER :: routineN = 'get_alist', routineP = moduleN//':'//routineN

      INTEGER                                            :: i

      NULLIFY (alist)
      i = locate(sap_int%asort, atom)
      IF (i > 0 .AND. i <= SIZE(sap_int%alist)) THEN
         i = sap_int%aindex(i)
         alist => sap_int%alist(i)
      ELSE IF (i == 0) THEN
         NULLIFY (alist)
      ELSE
         CPABORT("")
      END IF

   END SUBROUTINE get_alist

! **************************************************************************************************
!> \brief ...
!> \param blk_in ...
!> \param ldin ...
!> \param blk_out ...
!> \param ldout ...
!> \param ilist ...
!> \param in ...
!> \param jlist ...
!> \param jn ...
! **************************************************************************************************
   SUBROUTINE alist_pre_align_blk(blk_in, ldin, blk_out, ldout, ilist, in, jlist, jn)
      INTEGER, INTENT(IN)                                :: in, ilist(*), ldout
      REAL(dp), INTENT(INOUT)                            :: blk_out(ldout, *)
      INTEGER, INTENT(IN)                                :: ldin
      REAL(dp), INTENT(IN)                               :: blk_in(ldin, *)
      INTEGER, INTENT(IN)                                :: jlist(*), jn

      INTEGER                                            :: i, i0, i1, i2, i3, inn, inn1, j, j0

      inn = MOD(in, 4)
      inn1 = inn+1
      DO j = 1, jn
         j0 = jlist(j)
         DO i = 1, inn
            i0 = ilist(i)
            blk_out(i, j) = blk_in(i0, j0)
         ENDDO
         DO i = inn1, in, 4
            i0 = ilist(i)
            i1 = ilist(i+1)
            i2 = ilist(i+2)
            i3 = ilist(i+3)
            blk_out(i, j) = blk_in(i0, j0)
            blk_out(i+1, j) = blk_in(i1, j0)
            blk_out(i+2, j) = blk_in(i2, j0)
            blk_out(i+3, j) = blk_in(i3, j0)
         ENDDO
      ENDDO
   END SUBROUTINE alist_pre_align_blk

! **************************************************************************************************
!> \brief ...
!> \param blk_in ...
!> \param ldin ...
!> \param blk_out ...
!> \param ldout ...
!> \param ilist ...
!> \param in ...
!> \param jlist ...
!> \param jn ...
! **************************************************************************************************
   SUBROUTINE alist_post_align_blk(blk_in, ldin, blk_out, ldout, ilist, in, jlist, jn)
      INTEGER, INTENT(IN)                                :: in, ilist(*), ldout
      REAL(dp), INTENT(INOUT)                            :: blk_out(ldout, *)
      INTEGER, INTENT(IN)                                :: ldin
      REAL(dp), INTENT(IN)                               :: blk_in(ldin, *)
      INTEGER, INTENT(IN)                                :: jlist(*), jn

      INTEGER                                            :: i, i0, i1, i2, i3, inn, inn1, j, j0

      inn = MOD(in, 4)
      inn1 = inn+1
      DO j = 1, jn
         j0 = jlist(j)
         DO i = 1, inn
            i0 = ilist(i)
            blk_out(i0, j0) = blk_out(i0, j0)+blk_in(i, j)
         ENDDO
         DO i = inn1, in, 4
            i0 = ilist(i)
            i1 = ilist(i+1)
            i2 = ilist(i+2)
            i3 = ilist(i+3)
            blk_out(i0, j0) = blk_out(i0, j0)+blk_in(i, j)
            blk_out(i1, j0) = blk_out(i1, j0)+blk_in(i+1, j)
            blk_out(i2, j0) = blk_out(i2, j0)+blk_in(i+2, j)
            blk_out(i3, j0) = blk_out(i3, j0)+blk_in(i+3, j)
         ENDDO
      ENDDO
   END SUBROUTINE alist_post_align_blk

! **************************************************************************************************
!> \brief ...
!> \param sap_int ...
! **************************************************************************************************
   SUBROUTINE sap_sort(sap_int)
      TYPE(sap_int_type), DIMENSION(:), POINTER          :: sap_int

      CHARACTER(LEN=*), PARAMETER :: routineN = 'sap_sort', routineP = moduleN//':'//routineN

      INTEGER                                            :: iac, na

! *** Set up a sorting index

      DO iac = 1, SIZE(sap_int)
         IF (.NOT. ASSOCIATED(sap_int(iac)%alist)) CYCLE
         na = SIZE(sap_int(iac)%alist)
         ALLOCATE (sap_int(iac)%asort(na), sap_int(iac)%aindex(na))
         sap_int(iac)%asort(1:na) = sap_int(iac)%alist(1:na)%aatom
         CALL sort(sap_int(iac)%asort, na, sap_int(iac)%aindex)
      END DO

   END SUBROUTINE sap_sort

!==========================================================================================================

END MODULE sap_kind_types
