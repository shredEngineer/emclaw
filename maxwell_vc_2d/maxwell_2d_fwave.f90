! ===============================================================================
subroutine rpn2(ixy,maxnx,num_eqn,num_waves,num_aux,num_ghost,mx,ql,qr,auxl,auxr,fwave,s,amdq,apdq)
! ===============================================================================
!
!   This version outputs f-waves.

!   Riemann solver for the time dependent nonlinear Maxwell em equations in 1d,
!   in this case eps and mu dependend on time and position,
!   variable coefficients
!     kappa1(q,t,r)*(q1)_t + (q2)_x           = -(eps)_t*(q1)
!     kappa2(q,t,r)*(q2)_t + (q1)_y           = -(eps)_t*(q2)
!     kappa3(q,t,r)*(q3)_t + (q2)_y - (q1)_x  = -(mu)_t*(q3) 
!
!   where q1=Eq, q2=E, q3=H, eps=f(x,t), and mu=g(x,t)
!   and kappa1 = eps + 2*chi2_e_r*E1 + 3*chi3_e*E1^2
!   and kappa2 = eps + 2*chi2_e_r*E2 + 3*chi3_e*E2^2
!   and kappa3 = mu  + 2*chi2_m_r*H3 + 3*chi3_m*H3^2
!
!   function f(x_i,t_i) gives the permittivity value at the ith cell at step t_i
!   function g(x_i,t_i) gives the permeability value at the ith cell at step t_i
!      For RIP:   f(x_i,t_i)=f(x_i-v*t_i), and g(x_i,t_i)=g(x_i-v*t_i)
!   the system assumes the em functions to be some constant value + transient part

!   On input, ql contains the state vector at the left edge of each cell
!             qr contains the state vector at the right edge of each cell

!   On output, fwave contains the waves as jumps in f,
!              s the speeds,
!
!              amdq = A^- Delta q,
!              apdq = A^+ Delta q,
!                     the decomposition of the flux difference minus the source term
!                         f(qr(i-1)) - f(ql(i)) - \psi(q,x,t)
!                     into leftgoing and rightgoing parts respectively.
!

!   Note that the ith Riemann problem has left state qr(:,i-1)
!                                      and right state ql(:,i)
!   From the basic clawpack routines, this routine is called with ql = qr


    implicit none

    integer,          intent(in)  :: ixy, mx, num_ghost, maxnx, num_aux, num_eqn, num_waves

    double precision, intent(in)  :: auxl(num_aux,1-num_ghost:maxnx+num_ghost)
    double precision, intent(in)  :: auxr(num_aux,1-num_ghost:maxnx+num_ghost)
    double precision, intent(in)  ::   ql(num_eqn,1-num_ghost:maxnx+num_ghost)
    double precision, intent(in)  ::   qr(num_eqn,1-num_ghost:maxnx+num_ghost)
    
    double precision, intent(out) :: fwave(num_eqn,num_waves,1-num_ghost:maxnx+num_ghost)
    double precision, intent(out) ::    s(num_waves,1-num_ghost:maxnx+num_ghost)
    double precision, intent(out) :: apdq(num_eqn,1-num_ghost:maxnx+num_ghost)
    double precision, intent(out) :: amdq(num_eqn,1-num_ghost:maxnx+num_ghost)

    integer          :: i, m
    double precision :: q1i, q1im, q2i, q2im, q3i, q3im
    double precision :: b1, b2, b3
    double precision :: df1, df2, df3
    double precision :: eta1i, eta1im, eta2i, eta2im, eta3i, eta3im
    double precision :: ci, cim, zi, zim

!   split the jump in q at each interface into waves
!    print*, num_waves,num_eqn,num_ghost
    do i = 2-num_ghost, mx+num_ghost
        eta1i   = auxl(1,i  )
        eta1im  = auxr(1,i-1)
        eta2i   = auxl(2,i  )
        eta2im  = auxr(2,i-1)
        eta3i   = auxl(3,i  )
        eta3im  = auxr(3,i-1)

        q1i     = ql(1,i)
        q1im    = qr(1,i-1)
        q2i     = ql(2,i)
        q2im    = qr(2,i-1)
        q3i     = ql(3,i)
        q3im    = qr(3,i-1)

        if (ixy==1) then
            df2 = q3i/eta3i - q3im/eta3im
            df3 = q2i/eta2i - q2im/eta2im

            zi  = sqrt(eta2i/eta3i)
            zim = sqrt(eta2im/eta3im)

            ci  = 1.0d0/sqrt(eta2i*eta3i)
            cim = 1.0d0/sqrt(eta2im*eta3im)

            b1 = (-df2 + df3*zi)/(zi + zim)
            b2 = 0.d0
            b3 = (df2 + df3*zim)/(zi + zim)

            fwave(1,1,i) = 0.d0
            fwave(2,1,i) = b1*(-zim)
            fwave(3,1,i) = b1

            fwave(1,2,i) = 0.d0
            fwave(2,2,i) = b3*(zi)
            fwave(3,2,i) = b3

            s(1,i) = -cim
            s(2,i) = ci
        else
            df1 = q3i/eta3i - q3im/eta3im
            df3 = q1i/eta1i - q1im/eta1im

            zi  = sqrt(eta1i/eta3i)
            zim = sqrt(eta1im/eta3im)

            ci  = 1.0d0/sqrt(eta1i*eta3i)
            cim = 1.0d0/sqrt(eta1im*eta3im)

            b1 = -(df1 + df3*zi)/(zi + zim)
            b2 = 0.d0
            b3 = (df1 - df3*zim)/(zi + zim)

            fwave(1,1,i) = b1*(zim)
            fwave(2,1,i) = 0.d0
            fwave(3,1,i) = b1

            fwave(1,2,i) = b3*(-zi)
            fwave(2,2,i) = 0.d0
            fwave(3,2,i) = b3

            s(1,i) = -cim
            s(2,i) = ci
        endif   
    enddo

!     # compute the leftgoing and rightgoing fluctuations:
!     # Note s(1,i) < 0   and   s(2,i) > 0.

    do m=1,num_eqn
        do i = 2-num_ghost, mx+num_ghost
            amdq(m,i) = fwave(m,1,i)
            apdq(m,i) = fwave(m,2,i)
        enddo
    enddo

    return
end subroutine rpn2
