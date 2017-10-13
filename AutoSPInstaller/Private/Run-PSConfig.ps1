Function Run-PSConfig {
  Start-Process -FilePath $PSConfig -ArgumentList "-cmd upgrade -inplace b2b -force -cmd applicationcontent -install -cmd installfeatures -cmd secureresources" -NoNewWindow -Wait
}