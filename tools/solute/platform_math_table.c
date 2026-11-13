/* Identical binary64 arguments, native versus explicitly linked private probe. */
#include <math.h>
#include <stdio.h>
int main(void) {
  double (*functions[])(double)={exp,log,log10,sin,cos,tan,asin,acos,atan,sinh,cosh,tanh};
  const char *names[]={"exp","log","log10","sin","cos","tan","asin","acos","atan","sinh","cosh","tanh"};
  double args[]={0.0001,0.1,0.3,0.7,0.99};
  for(int i=0;i<12;i++)for(int j=0;j<5;j++)
    printf("%s %a %a\n",names[i],args[j],functions[i](args[j]));
  for(int j=0;j<5;j++)printf("pow %a %a\n",args[j],pow(args[j],1.37));
  return 0;
}
