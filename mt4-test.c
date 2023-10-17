

#property strict


int OnInit(){
    Print("账户余额:",AccountBalance());
    Print("账户公司:",AccountCompany());
    Print("货币名称",AccountCurrency());
    Print("当前杠杆",AccountLeverage());
    Print("当前品种",Symbol());
    return(INIT_SUCCEEDED);
}