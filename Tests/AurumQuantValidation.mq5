#property script_show_inputs
#property strict
#include <AurumQuant/Research/ValidationSuite.mqh>
void OnStart(){int passed=0,failed=0;if(!AQValidationSuite::Run(passed,failed))SetUserError(9001);}
