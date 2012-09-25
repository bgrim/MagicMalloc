#include<stdio.h>
#include<cuda_runtime.h>

struct memoryPointer{
  memoryPointer *ptr;
  unsigned size;
  unsigned *data;
};

typedef struct memoryPointer MemoryPointer;

static MemoryPointer base;
static MemoryPointer *freep = NULL;

void fastAddList(MemoryPointer *bp){
  MemoryPointer *p;

  for(p = freep; !(bp->data > p->data && bp->data < (p->ptr)->data); p = p->ptr)
    if(p->data >= (p->ptr)->data && (bp->data > p->data || bp->data < (p->ptr)->data)) 
      break;

  if( ((MemoryPointer *) (((char *)bp->data) + bp->size)) == p->ptr){
    bp->size += (p->ptr)->size;
    bp->ptr = (p->ptr)->ptr;
    cudaMemcpy(bp->data, &bp->size, sizeof(unsigned), cudaMemcpyHostToDevice);
    free(p->ptr);
  }else
    bp->ptr = p->ptr;

  if(  ((MemoryPointer *) (((char *)p->data) + p->size)) == bp){
    p->size += bp->size;
    p->ptr = bp->ptr;
    cudaMemcpy(p->data, &p->size, sizeof(unsigned), cudaMemcpyHostToDevice);
    free(bp);
  }else
    p->ptr = bp;
  
  freep = p;
}

void fastFree(void *loc){
  loc = ((void *)(((char *)loc)-sizeof(unsigned)));
  MemoryPointer *v = (MemoryPointer *) malloc(sizeof(MemoryPointer));
  cudaMemcpy(&v->size, loc, sizeof(unsigned), cudaMemcpyDeviceToHost);
  v->data = (unsigned *) loc;
  fastAddList(v);
}


static MemoryPointer *morecore(unsigned nu){
  void *cp;
  MemoryPointer *up = (MemoryPointer *)malloc(sizeof(MemoryPointer));
  if (nu < 1048576) nu = 1048576;
  cudaMalloc(&cp, nu);

  up->data = (unsigned *)cp;

  up->size = nu;
  cudaMemcpy(cp,&(up->size),sizeof(unsigned),cudaMemcpyHostToDevice);

  fastAddList(up);
  return freep;
}



void *fastMalloc(unsigned nbytes){
  MemoryPointer *p, *prevp;
  if ((prevp = freep)==NULL){
    base.ptr = freep = prevp = &base;
    base.size = 0;
  }
  nbytes+=sizeof(unsigned);
  char *loc;
  for(p = prevp->ptr; ;prevp = p, p = p->ptr){
    if(p->size >= nbytes){
      if(p->size == nbytes){
        prevp->ptr = p->ptr;
        loc = (char *) p->data;
        free(p);
      }else{
        p->size -= nbytes;
        loc =((char *) p->data)+p->size;
      }
      freep = prevp;
      cudaMemcpy(loc,&nbytes,sizeof(unsigned),cudaMemcpyHostToDevice);
      return (void *)(loc+sizeof(unsigned));
    }
    if (p == freep)
      if((p = morecore(nbytes))==NULL)
        return NULL;
  }
}


int main(int argc, char **argv){
  void *v;
  int i, cap=0;
  if(argc>1)cap=atoi(argv[1]);
  for(i=0; i<cap; i++){
    v = fastMalloc(1);
  }
}
