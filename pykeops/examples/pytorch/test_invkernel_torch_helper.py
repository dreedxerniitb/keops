"""
KernelSolve reduction
===========================

Let's see how to solve discrete deconvolution problems
using the **conjugate gradient solver** provided by
:func:`pykeops.torch.KernelSolve`.
"""

###############################################################################
# Setup
# ----------------
#
# Standard imports:
#

import time 
from matplotlib import pyplot as plt

import torch

from pykeops import Vi, Vj, Pm
from pykeops import keops_formula as keops


###############################################################################
# Define our dataset:
#

N  = 5000 if torch.cuda.is_available() else 500  # Number of points
D  = 2      # Dimension of the ambient space
Dv = 2      # Dimension of the vectors (= number of linear problems to solve)
sigma = .1  # Radius of our RBF kernel    

x = torch.rand(N, D, requires_grad=True)
b = torch.rand(N, Dv)
g = torch.Tensor([ .5 / sigma**2])  # Parameter of the Gaussian RBF kernel
alpha = 0.01 # ridge regularization

###############################################################################
# .. note::
#   This operator uses a conjugate gradient solver and assumes
#   that **formula** defines a **symmetric**, positive and definite
#   **linear** reduction with respect to the alias ``"b"``
#   specified trough the third argument.
#
# Apply our solver on arbitrary point clouds:
#

print("Solving a Gaussian linear system, with {} points in dimension {}.".format(N,D))
start = time.time()
K_xx = keops.exp(-keops.sum( (Vi(x) - Vj(x))**2,dim=2) / (2*sigma**2) )
cfun = keops.kernelsolve(K_xx,Vi(b),alpha=alpha,call=False)
c = cfun()
end = time.time()
print('Timing (KeOps implementation):', round(end - start, 5), 's')

###############################################################################
# Compare with a straightforward PyTorch implementation:
#

start = time.time()
K_xx = alpha * torch.eye(N) + torch.exp( -torch.sum( (x[:,None,:] - x[None,:,:])**2,dim=2) / (2*sigma**2) )
c_py = torch.gesv(b, K_xx)[0]
end = time.time()
print('Timing (PyTorch implementation):', round(end - start, 5), 's')
print("Relative error = ",(torch.norm(c - c_py) / torch.norm(c_py)).item())


# Plot the results next to each other:
for i in range(Dv):
    plt.subplot(Dv, 1, i+1)
    plt.plot(   c.cpu().detach().numpy()[:40,i],  '-', label='KeOps')
    plt.plot(c_py.cpu().detach().numpy()[:40,i], '--', label='PyTorch')
    plt.legend(loc='lower right')
plt.tight_layout() ; plt.show()


###############################################################################
# Compare the derivatives:
#

print(cfun.callfun)

print("1st order derivative")
e = torch.randn(N,D)
start = time.time()
u, = torch.autograd.grad(c, x, e)
end = time.time()
print('Timing (KeOps derivative):', round(end - start, 5), 's')
start = time.time()
u_py, = torch.autograd.grad(c_py, x, e)
end = time.time()
print('Timing (PyTorch derivative):', round(end - start, 5), 's')
print("Relative error = ",(torch.norm(u - u_py) / torch.norm(u_py)).item())



# Plot the results next to each other:
for i in range(Dv):
    plt.subplot(Dv, 1, i+1)
    plt.plot(   u.cpu().detach().numpy()[:40,i],  '-', label='KeOps')
    plt.plot(u_py.cpu().detach().numpy()[:40,i], '--', label='PyTorch')
    plt.legend(loc='lower right')
plt.tight_layout() ; plt.show()