#include <stdio.h>
#include <math.h>
#include "tree_sitter/api.h"

#define FOO BAR
#define Foo(x, y) x + 1
int main(){
  // ignore開始
  for (; ; ) {
    printf("Hello WOrld");
    1 + 2;
    3 + 4;
    for (;;) {}
  }// end-ignore
  while (true) {
    /* format: ignore */
  }
  if (true || x == 2) {
    printf("Hello World %s", "me", "you");
  }
}

